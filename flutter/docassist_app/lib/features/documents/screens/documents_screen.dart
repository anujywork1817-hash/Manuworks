import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../providers/document_provider.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentProvider.notifier).loadDocuments();
    });
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    final success = await ref.read(documentProvider.notifier).uploadDocument(file.path!, file.name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '${file.name} uploaded!' : 'Upload failed'),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);
    final theme = Theme.of(context);
    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.read(documentProvider.notifier).loadDocuments()),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: state.isUploading ? null : _pickAndUpload,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Upload Document',
        child: const Icon(Icons.upload_file_outlined),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search documents...', prefixIcon: Icon(Icons.search_outlined)),
            onChanged: (v) => ref.read(documentProvider.notifier).loadDocuments(search: v),
          ),
        ),
        if (state.isUploading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Uploading... ${(state.uploadProgress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: state.uploadProgress),
              const SizedBox(height: AppSpacing.md),
            ]),
          ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(color: AppColors.errorContainer, borderRadius: AppRadius.md),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(state.error!, style: const TextStyle(color: AppColors.error))),
              ]),
            ),
          ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.documents.isEmpty
                  ? _EmptyState(onUpload: _pickAndUpload)
                  : RefreshIndicator(
                      onRefresh: () => ref.read(documentProvider.notifier).loadDocuments(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: state.documents.length,
                        itemBuilder: (context, i) => _DocumentCard(
                          document: state.documents[i],
                          onTap: () { debugPrint('NAV TO DOC ID: ${state.documents[i].id}'); context.push('/documents/${state.documents[i].id}'); },
                          onDelete: () => _confirmDelete(context, state.documents[i]),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, Document doc) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Document'),
      content: Text('Delete "${doc.title}"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async { Navigator.pop(ctx); await ref.read(documentProvider.notifier).deleteDocument(doc.id); },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ));
  }
}

class _DocumentCard extends StatelessWidget {
  final Document document; final VoidCallback onTap; final VoidCallback onDelete;
  const _DocumentCard({required this.document, required this.onTap, required this.onDelete});

  Color get _typeColor {
    switch (document.fileType.toLowerCase()) {
      case 'pdf': return AppColors.pdfColor;
      case 'docx': case 'doc': return AppColors.docxColor;
      default: return AppColors.txtColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap, borderRadius: AppRadius.lg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: _typeColor.withValues(alpha: 0.1), borderRadius: AppRadius.md),
              child: Center(child: Text(document.fileType.toUpperCase(),
                  style: TextStyle(color: _typeColor, fontWeight: FontWeight.bold, fontSize: 11))),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(document.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Flexible(
                  child: Text(
                    '${document.fileSizeHuman} · ${timeago.format(document.createdAt)}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (document.isProcessed) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.auto_awesome, size: 11, color: theme.colorScheme.primary),
                  const SizedBox(width: 2),
                  Text('AI ready',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ]),
            ])),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_outlined),
              onSelected: (v) { if (v == 'delete') onDelete(); },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ])),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.folder_open_outlined, size: 80, color: AppColors.textTertiary),
    const SizedBox(height: AppSpacing.md),
    Text('No documents yet', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: AppSpacing.sm),
    Text('Upload your first PDF or DOCX', style: Theme.of(context).textTheme.bodyMedium),
    const SizedBox(height: AppSpacing.lg),
    ElevatedButton.icon(onPressed: onUpload, icon: const Icon(Icons.upload_file_outlined), label: const Text('Upload Document')),
  ]));
}

