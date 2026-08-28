import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../documents/providers/document_provider.dart';
import '../../../core/services/ai_history_service.dart';
import '../../../shared/widgets/feature_history_sheet.dart';
import '../../../shared/widgets/fun_loading_word.dart';
import '../../../shared/widgets/share_options_sheet.dart';
import '../../../core/services/document_export_service.dart';
import '../../../core/services/clipboard_helper.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  Document? _doc1;
  Document? _doc2;
  bool _comparing = false;
  Map<String, dynamic>? _result;
  String? _error;

  // Which slot ('A' or 'B') is currently mid-upload, if any — drives the
  // per-selector spinner while a freshly-picked file uploads and processes.
  String? _uploadingSlot;
  String? _uploadingStatus;

  @override
  void initState() {
    super.initState();
    // The document list is loaded lazily by the Documents tab. If the user
    // opens Compare directly (e.g. from the dashboard) that list is still
    // empty, leaving both pickers with nothing to select — so load it here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(documentProvider).documents.isEmpty) {
        ref.read(documentProvider.notifier).loadDocuments();
      }
    });
  }

  Future<void> _compare() async {
    if (_doc1 == null || _doc2 == null) return;
    if (_doc1!.id == _doc2!.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select two different documents'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() { _comparing = true; _result = null; _error = null; });
    try {
      final res = await DioClient.post<Map<String, dynamic>>('/ai/compare', data: {
        'doc1_id': _doc1!.id,
        'doc2_id': _doc2!.id,
      });
      final data = res['data'] as Map<String, dynamic>;
      if (mounted) {
        setState(() { _result = data; _comparing = false; });
      }
      try {
        final summary = data['summary'] as String? ?? '';
        final verdict = data['verdict'] as String? ?? '';
        await AiHistoryService.save(
          featureId: 'compare',
          title: 'Compare · ${_doc1!.title} vs ${_doc2!.title}',
          subtitle: verdict,
          content: [
            if (summary.isNotEmpty) summary,
            if (verdict.isNotEmpty) 'Verdict: $verdict',
          ].join('\n\n'),
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().contains('Daily AI')
              ? 'Daily AI limit reached. Try again later.'
              : 'Comparison failed: ${e.toString()}';
          _comparing = false;
        });
      }
    }
  }

  /// Lets the user pick a file straight from their device (instead of
  /// choosing from already-uploaded documents), uploads it, waits for
  /// processing to finish (comparison needs the extracted text), and drops
  /// the result into slot A or B.
  Future<void> _uploadNewDocument(bool isDocA) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
      withData: true, // required on mobile/desktop to get bytes for web-style upload; web always includes bytes
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    setState(() {
      _uploadingSlot = isDocA ? 'A' : 'B';
      _uploadingStatus = 'Uploading...';
      _error = null;
    });

    final docId =
        await ref.read(documentProvider.notifier).uploadPlatformFile(file);
    if (!mounted) return;
    if (docId == null) {
      setState(() {
        _uploadingSlot = null;
        _error = 'Upload failed: ${ref.read(documentProvider).error ?? file.name}';
      });
      return;
    }

    setState(() => _uploadingStatus = 'Processing...');

    // Poll until the document is ready (or failed) — comparison needs the
    // extracted text, so the freshly-uploaded file must finish OCR first.
    Document? readyDoc;
    for (int i = 0; i < 40; i++) {
      await Future.delayed(Duration(seconds: i < 10 ? 2 : 4));
      if (!mounted) return;
      try {
        final res = await DioClient.get('/documents/$docId');
        final doc = Document.fromJson(res['data']);
        if (doc.status == 'ready') {
          readyDoc = doc;
          break;
        }
        if (doc.status == 'failed') {
          setState(() {
            _uploadingSlot = null;
            _error = '${file.name} failed to process.';
          });
          return;
        }
      } catch (_) {
        // transient network hiccup — just try again next tick
      }
    }

    if (!mounted) return;
    if (readyDoc == null) {
      setState(() {
        _uploadingSlot = null;
        _error = '${file.name} is taking longer than expected to process. '
            'It will appear in "Choose from Documents" once ready.';
      });
      return;
    }

    setState(() {
      _uploadingSlot = null;
      if (isDocA) {
        _doc1 = readyDoc;
      } else {
        _doc2 = readyDoc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Document Comparison',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Compare history',
            icon: const Icon(Icons.history_rounded, color: AppColors.textPrimary),
            onPressed: () => showFeatureHistorySheet(
                context, featureId: 'compare', featureLabel: 'Document Comparison'),
          ),
          if (_result != null)
            TextButton.icon(
              onPressed: () => setState(() { _result = null; _doc1 = null; _doc2 = null; }),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('New'),
            ),
        ],
      ),
      body: _result != null ? _buildResult() : _buildSelector(),
    );
  }

  // ── Document selector ────────────────────────────────────────────────────────

  Widget _buildSelector() {
    final state = ref.watch(documentProvider);

    if (state.isLoading && state.documents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.documents.isEmpty) {
      return Center(child: Text('Failed to load documents: ${state.error}'));
    }
    final docs = state.documents;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              Icon(Icons.compare_arrows_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Select two documents to compare. AI will identify all meaningful differences between them.',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              )),
            ]),
          ),

          const SizedBox(height: 20),

          // Document A
          _DocSelector(
            label: 'Document A',
            color: AppColors.secondary,
            selected: _doc1,
            docs: docs,
            excludeId: _doc2?.id,
            onSelected: (d) => setState(() => _doc1 = d),
            onUploadNew: () => _uploadNewDocument(true),
            uploading: _uploadingSlot == 'A',
            uploadingStatus: _uploadingStatus,
          ),

          const SizedBox(height: 12),

          // VS divider
          Row(children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.sm,
              ),
              child: const Text('VS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ]),

          const SizedBox(height: 12),

          // Document B
          _DocSelector(
            label: 'Document B',
            color: AppColors.info,
            selected: _doc2,
            docs: docs,
            excludeId: _doc1?.id,
            onSelected: (d) => setState(() => _doc2 = d),
            onUploadNew: () => _uploadNewDocument(false),
            uploading: _uploadingSlot == 'B',
            uploadingStatus: _uploadingStatus,
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13))),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_doc1 == null || _doc2 == null || _comparing) ? null : _compare,
              icon: _comparing
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface))
                  : const Icon(Icons.compare_arrows_rounded),
              label: _comparing
                  ? FunLoadingWord(
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.surface))
                  : const Text('Compare Documents'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      );
  }

  // ── Result view ──────────────────────────────────────────────────────────────

  String _reportText(List<Map<String, dynamic>> diffs, String summary, String verdict) {
    final buf = StringBuffer()
      ..writeln('# Document Comparison')
      ..writeln('${_doc1?.title ?? 'Document A'} vs ${_doc2?.title ?? 'Document B'}')
      ..writeln()
      ..writeln('## Summary')
      ..writeln(summary)
      ..writeln();
    if (diffs.isNotEmpty) {
      buf.writeln('## ${_doc1?.title ?? 'Document A'}');
      for (final d in diffs) {
        final text = d['doc_a'] as String? ?? '';
        if (text.isEmpty || d['change'] == 'added') continue;
        buf.writeln('- [${d['category'] ?? ''}] $text');
      }
      buf.writeln();
      buf.writeln('## ${_doc2?.title ?? 'Document B'}');
      for (final d in diffs) {
        final text = d['doc_b'] as String? ?? '';
        if (text.isEmpty || d['change'] == 'removed') continue;
        buf.writeln('- [${d['category'] ?? ''}] $text');
      }
      buf.writeln();
    }
    if (verdict.isNotEmpty) {
      buf.writeln('## Key Takeaway');
      buf.writeln(verdict);
    }
    return buf.toString();
  }

  String _sideText(List<Map<String, dynamic>> diffs, {required bool isA}) {
    final buf = StringBuffer();
    for (final d in diffs) {
      final text = (isA ? d['doc_a'] : d['doc_b']) as String? ?? '';
      if (text.isEmpty) continue;
      if (isA && d['change'] == 'added') continue;
      if (!isA && d['change'] == 'removed') continue;
      buf.writeln('[${d['category'] ?? ''}] $text');
      buf.writeln();
    }
    return buf.toString().trim();
  }

  Future<void> _handleExport(
    Future<void> Function() action, {
    required String busyMessage,
    required String doneMessage,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(busyMessage), duration: const Duration(seconds: 2)),
    );
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _exportPdf(String content) => _handleExport(
        () => DocumentExportService.exportReportToPdf(
            title: 'Document Comparison', content: content),
        busyMessage: 'Preparing PDF...',
        doneMessage: 'PDF ready to save or share',
      );

  Future<void> _exportDocx(String content) => _handleExport(
        () => DocumentExportService.exportReportToDocx(
            title: 'Document Comparison', content: content),
        busyMessage: 'Preparing Word file...',
        doneMessage: 'DOCX ready to save or share',
      );

  static const _colorA = AppColors.secondary;
  static const _colorB = AppColors.info;

  Widget _buildResult() {
    final diffs = (_result!['differences'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final summary = _result!['summary'] as String? ?? '';
    final verdict = _result!['verdict'] as String? ?? '';
    final totalChanges = _result!['total_changes'] as int? ?? diffs.length;
    final reportText = _reportText(diffs, summary, verdict);

    return CustomScrollView(slivers: [

      // ── Premium gradient header: titles, change badge, actions, summary ──
      SliverToBoxAdapter(child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_colorA, _colorB],
            ),
            boxShadow: [
              BoxShadow(color: Color(0x33334155), blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          child: Stack(children: [
            Positioned(top: -30, right: -20,
                child: _Orb(size: 110, color: Colors.white.withValues(alpha: 0.10))),
            Positioned(bottom: -30, left: -10,
                child: _Orb(size: 90, color: Colors.white.withValues(alpha: 0.08))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _DocPill(_doc1!.title, Colors.white)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 20),
                  ),
                  Expanded(child: _DocPill(_doc2!.title, Colors.white)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$totalChanges difference${totalChanges == 1 ? '' : 's'} found',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                    tooltip: 'Share',
                    onPressed: () => showShareOptionsSheet(context,
                        title: 'Document Comparison', content: reportText),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 18),
                    tooltip: 'Download as PDF',
                    onPressed: () => _exportPdf(reportText),
                  ),
                  IconButton(
                    icon: const Icon(Icons.description_outlined, color: Colors.white, size: 18),
                    tooltip: 'Download as Word (DOCX)',
                    onPressed: () => _exportDocx(reportText),
                  ),
                ]),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(summary, style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.white)),
                ],
              ]),
            ),
          ]),
        ),
      )),

      // ── Side-by-side comparison panels ──────────────────────────────────
      if (diffs.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LayoutBuilder(builder: (context, constraints) {
              final panelA = _ComparisonPanel(
                label: 'Document A', docTitle: _doc1!.title, color: _colorA,
                diffs: diffs, isA: true,
                onCopy: () async {
                  final ok = await copyToClipboard(_sideText(diffs, isA: true));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Document A differences copied' : 'Copy failed')));
                  }
                },
              );
              final panelB = _ComparisonPanel(
                label: 'Document B', docTitle: _doc2!.title, color: _colorB,
                diffs: diffs, isA: false,
                onCopy: () async {
                  final ok = await copyToClipboard(_sideText(diffs, isA: false));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Document B differences copied' : 'Copy failed')));
                  }
                },
              );
              final wide = constraints.maxWidth >= 680;
              return wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: panelA),
                      const SizedBox(width: 12),
                      Expanded(child: panelB),
                    ])
                  : Column(children: [panelA, const SizedBox(height: 12), panelB]);
            }),
          ),
        ),

      // Verdict
      if (verdict.isNotEmpty)
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.successContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Key Takeaway',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: AppColors.success)),
                const SizedBox(height: 4),
                Text(verdict, style: const TextStyle(fontSize: 13, height: 1.5,
                    color: AppColors.success)),
              ])),
            ]),
          ),
        )),

      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ]);
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ─── Side-by-side comparison panel ("ChatGPT-style" A/B card) ─────────────────

class _ComparisonPanel extends StatelessWidget {
  final String label;
  final String docTitle;
  final Color color;
  final List<Map<String, dynamic>> diffs;
  final bool isA;
  final VoidCallback onCopy;
  const _ComparisonPanel({
    required this.label, required this.docTitle, required this.color,
    required this.diffs, required this.isA, required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final entries = diffs.where((d) {
      final text = (isA ? d['doc_a'] : d['doc_b']) as String? ?? '';
      if (text.isEmpty) return false;
      if (isA && d['change'] == 'added') return false;
      if (!isA && d['change'] == 'removed') return false;
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: color, letterSpacing: 0.5)),
              Text(docTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ])),
            IconButton(
              icon: Icon(Icons.copy_rounded, size: 16, color: color),
              tooltip: 'Copy all',
              onPressed: entries.isEmpty ? null : onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ]),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('No unique content on this side.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = entries[i];
                final text = (isA ? d['doc_a'] : d['doc_b']) as String? ?? '';
                final category = d['category'] as String? ?? '';
                final change = d['change'] as String? ?? '';
                final changeColor = switch (change) {
                  'added' => AppColors.success,
                  'removed' => AppColors.error,
                  'modified' => AppColors.warning,
                  _ => AppColors.textSecondary,
                };
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: changeColor, width: 3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (category.isNotEmpty)
                      Text(category, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                          color: changeColor, letterSpacing: 0.3)),
                    const SizedBox(height: 3),
                    Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5,
                        color: AppColors.textPrimary)),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ─── Document selector tile ───────────────────────────────────────────────────

class _DocSelector extends StatelessWidget {
  final String label;
  final Color color;
  final Document? selected;
  final List<Document> docs;
  final String? excludeId;
  final ValueChanged<Document> onSelected;
  final VoidCallback onUploadNew;
  final bool uploading;
  final String? uploadingStatus;

  const _DocSelector({
    required this.label, required this.color, required this.selected,
    required this.docs, required this.onSelected, required this.onUploadNew,
    this.uploading = false, this.uploadingStatus,
    this.excludeId,
  });

  @override
  Widget build(BuildContext context) {
    final available = docs.where((d) => d.id != excludeId).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected != null ? color : AppColors.outline,
          width: selected != null ? 1.5 : 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: color, letterSpacing: 0.5)),
          ]),
        ),
        if (uploading)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color)),
              const SizedBox(width: 10),
              FunLoadingWord(
                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            ]),
          )
        else ...[
          if (selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(selected!.fileType.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(selected!.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary))),
                GestureDetector(
                  onTap: () => _showPicker(context, available),
                  child: Icon(Icons.swap_horiz_rounded, color: color, size: 20),
                ),
              ]),
            ),
          if (selected == null)
            InkWell(
              onTap: () => _showPicker(context, available),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(children: [
                  Icon(Icons.add_circle_outline, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text('Tap to select document',
                      style: TextStyle(fontSize: 13, color: color,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
        ],
      ]),
    );
  }

  void _showPicker(BuildContext context, List<Document> available) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocPickerSheet(
        docs: available,
        color: color,
        label: label,
        onSelected: onSelected,
        onUploadNew: onUploadNew,
      ),
    );
  }
}

// ─── Bottom sheet picker ─────────────────────────────────────────────────────

class _DocPickerSheet extends StatefulWidget {
  final List<Document> docs;
  final Color color;
  final String label;
  final ValueChanged<Document> onSelected;
  final VoidCallback onUploadNew;
  const _DocPickerSheet({required this.docs, required this.color,
      required this.onUploadNew,
      required this.label, required this.onSelected});

  @override
  State<_DocPickerSheet> createState() => _DocPickerSheetState();
}

class _DocPickerSheetState extends State<_DocPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.docs
        : widget.docs.where((d) =>
            d.title.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFEEEDF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('Select ${widget.label}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onUploadNew();
              },
              icon: Icon(Icons.upload_file_rounded, size: 17, color: widget.color),
              label: Text('Upload from device (PC / Mobile)',
                  style: TextStyle(fontSize: 13, color: widget.color, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: widget.color.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('or choose an existing document',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textTertiary),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: widget.color, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(child: ListView.builder(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final doc = filtered[i];
              return GestureDetector(
                onTap: () { Navigator.pop(context); widget.onSelected(doc); },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(doc.fileType.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                              color: widget.color)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(doc.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary))),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
                  ]),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
}

// ─── Doc label pill ───────────────────────────────────────────────────────────

class _DocPill extends StatelessWidget {
  final String title;
  final Color color;
  const _DocPill(this.title, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(title,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}