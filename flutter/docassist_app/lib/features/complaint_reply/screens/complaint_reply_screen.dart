import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';

class ComplaintReplyScreen extends ConsumerStatefulWidget {
  const ComplaintReplyScreen({super.key});

  @override
  ConsumerState<ComplaintReplyScreen> createState() =>
      _ComplaintReplyScreenState();
}

class _ComplaintReplyScreenState extends ConsumerState<ComplaintReplyScreen> {
  PlatformFile? _complaintFile;
  PlatformFile? _replyFile;
  bool _generating = false;
  bool _downloading = false;

  String? _replyText;
  List<String> _modifiedSections = [];
  String? _summary;
  String? _error;

  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickComplaintPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() { _complaintFile = result.files.first; _error = null; });
    }
  }

  Future<void> _pickReplyDOCX() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() { _replyFile = result.files.first; _error = null; });
    }
  }

  Future<void> _generate() async {
    if (_complaintFile == null || _replyFile == null) return;
    if (_complaintFile!.path == null || _replyFile!.path == null) {
      setState(() => _error = 'Cannot access file path. Please try again.');
      return;
    }

    setState(() { _generating = true; _error = null; _replyText = null; });

    try {
      final formData = FormData.fromMap({
        'complaint_pdf': await MultipartFile.fromFile(
          _complaintFile!.path!,
          filename: _complaintFile!.name,
        ),
        'reply_docx': await MultipartFile.fromFile(
          _replyFile!.path!,
          filename: _replyFile!.name,
        ),
      });

      final response = await DioClient.instance.post(
        '/ai/complaint-reply',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      final body = response.data as Map<String, dynamic>;
      if (!(body['success'] as bool? ?? false)) {
        throw Exception(body['message'] ?? 'Generation failed');
      }

      final data = body['data'] as Map<String, dynamic>;
      final replyText = (data['reply_text'] as String?) ?? '';
      final sections = (data['modified_sections'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];
      final summary = (data['summary'] as String?) ?? '';

      if (mounted) {
        setState(() {
          _replyText = replyText;
          _modifiedSections = sections;
          _summary = summary;
          _editCtrl.text = replyText;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final msg = e.toString();
          _error = msg.contains('Daily AI')
              ? 'Daily AI limit reached. Please try again later.'
              : msg.contains('Exception:')
                  ? msg.replaceFirst('Exception: ', '')
                  : 'Generation failed: $msg';
          _generating = false;
        });
      }
    }
  }

  Future<void> _downloadDocx() async {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _downloading = true);
    try {
      final response = await DioClient.instance.post(
        '/ai/complaint-reply/download',
        data: {'text': text, 'filename': 'complaint_reply.docx'},
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      final Directory dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) await dir.create(recursive: true);
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/complaint_reply_$ts.docx');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('DOCX saved and opened'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _reset() => setState(() {
        _replyText = null;
        _modifiedSections = [];
        _summary = null;
        _complaintFile = null;
        _replyFile = null;
        _error = null;
        _editCtrl.clear();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Complaint Reply Generator',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          if (_replyText != null)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('New'),
            ),
        ],
      ),
      body: _replyText != null ? _buildResult() : _buildForm(),
    );
  }

  // ── Form view ─────────────────────────────────────────────────────────────────

  Widget _buildForm() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upload the complaint PDF and an existing reply DOCX template. AI will generate a new reply adapting the template to the new complaint.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.info, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Step 1
          _stepLabel('1', 'Upload Complaint PDF'),
          const SizedBox(height: 8),
          _fileCard(
            file: _complaintFile,
            hint: 'Tap to select the complaint PDF',
            icon: Icons.picture_as_pdf_outlined,
            accentColor: AppColors.error,
            onTap: _pickComplaintPDF,
          ),
          const SizedBox(height: 16),

          // Step 2
          _stepLabel('2', 'Upload Existing Reply Template (.docx)'),
          const SizedBox(height: 8),
          _fileCard(
            file: _replyFile,
            hint: 'Tap to select the existing reply Word document',
            icon: Icons.description_outlined,
            accentColor: AppColors.info,
            onTap: _pickReplyDOCX,
          ),
          const SizedBox(height: 24),

          // Error
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13))),
              ]),
            ),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_complaintFile != null &&
                      _replyFile != null &&
                      !_generating)
                  ? _generate
                  : null,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.surface))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                  _generating ? 'Generating reply...' : 'Generate Complaint Reply'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      );

  // ── Result view ───────────────────────────────────────────────────────────────

  Widget _buildResult() => Column(children: [
        // Action toolbar
        Container(
          color: AppColors.surface,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Expanded(
              child: Text('Generated Reply',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _editCtrl.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: const Icon(Icons.copy, size: 15),
              label: const Text('Copy'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _downloading ? null : _downloadDocx,
              icon: _downloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.surface))
                  : const Icon(Icons.download_outlined, size: 15),
              label: const Text('DOCX'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Summary card
              if (_summary != null && _summary!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.check_circle_outline,
                              color: AppColors.success, size: 15),
                          SizedBox(width: 6),
                          Text('Reply Generated',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success)),
                        ]),
                        const SizedBox(height: 6),
                        Text(_summary!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                height: 1.4)),
                      ]),
                ),
                const SizedBox(height: 14),
              ],

              // Modified sections chips
              if (_modifiedSections.isNotEmpty) ...[
                const Text('Modified Sections',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _modifiedSections
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.warningContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Text(s,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w500)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Editable reply text
              const Text('Reply Text (Editable)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                  boxShadow: AppShadows.sm,
                ),
                child: TextField(
                  controller: _editCtrl,
                  maxLines: null,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.7,
                    color: AppColors.primaryLight,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]);

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _stepLabel(String number, String label) => Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(number,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textOnPrimary)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]);

  Widget _fileCard({
    required PlatformFile? file,
    required String hint,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: file != null
                ? accentColor.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: file != null
                  ? accentColor.withValues(alpha: 0.45)
                  : AppColors.outline,
              width: file != null ? 1.5 : 1,
            ),
          ),
          child: file != null
              ? Row(children: [
                  Icon(icon, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(file.name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accentColor)),
                        if (file.size > 0)
                          Text(
                              '${(file.size / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                      ])),
                  Icon(Icons.check_circle_rounded,
                      color: accentColor, size: 20),
                ])
              : Row(children: [
                  const Icon(Icons.upload_outlined,
                      color: AppColors.textTertiary, size: 22),
                  const SizedBox(width: 12),
                  Text(hint,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ]),
        ),
      );
}
