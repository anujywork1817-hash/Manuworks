import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class OcrScanScreen extends StatefulWidget {
  const OcrScanScreen({super.key});

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _scanning = false;
  String? _text;
  int _wordCount = 0;
  int _pageCount = 0;
  double _confidence = 0;
  String? _error;
  String _language = 'en';

  static const _languages = [
    ('en', 'English'),
    ('hi', 'Hindi'),
    ('mr', 'Marathi'),
    ('gu', 'Gujarati'),
    ('ta', 'Tamil'),
    ('te', 'Telugu'),
    ('kn', 'Kannada'),
    ('ml', 'Malayalam'),
    ('pa', 'Punjabi'),
    ('bn', 'Bengali'),
    ('ur', 'Urdu'),
  ];

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2400,
    );
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _text = null;
      _error = null;
    });
  }

  Future<void> _extract() async {
    if (_image == null) return;
    setState(() { _scanning = true; _error = null; _text = null; });

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_image!.path,
            filename: _image!.path.split(Platform.pathSeparator).last),
        'language': _language,
      });

      final response = await DioClient.uploadFile('/ocr/scan', formData);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ApiException(message: body['message'] ?? 'OCR failed');
      }
      final data = body['data'] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _text = (data['text'] as String?) ?? '';
          _wordCount = (data['word_count'] as num?)?.toInt() ?? 0;
          _pageCount = (data['page_count'] as num?)?.toInt() ?? 1;
          _confidence = (data['confidence'] as num?)?.toDouble() ?? 0;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Extraction failed: ${e.toString()}';
          _scanning = false;
        });
      }
    }
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
        title: const Text('OCR Scanner',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          if (_text != null)
            TextButton.icon(
              onPressed: () => setState(() { _text = null; _image = null; }),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('New Scan'),
            ),
        ],
      ),
      body: _text != null ? _buildResult() : _buildScanView(),
    );
  }

  Widget _buildScanView() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Language selector
      const Text('Document Language',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, letterSpacing: 0.4)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _language,
            isExpanded: true,
            onChanged: (v) => setState(() => _language = v!),
            items: _languages.map((l) => DropdownMenuItem(
              value: l.$1,
              child: Text(l.$2, style: const TextStyle(fontSize: 14)),
            )).toList(),
          ),
        ),
      ),

      const SizedBox(height: 20),

      // Capture buttons
      const Text('Capture Image',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, letterSpacing: 0.4)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _captureBtn(
          Icons.camera_alt_outlined, 'Camera', AppColors.secondary,
          () => _pick(ImageSource.camera),
        )),
        const SizedBox(width: 12),
        Expanded(child: _captureBtn(
          Icons.photo_library_outlined, 'Gallery', AppColors.info,
          () => _pick(ImageSource.gallery),
        )),
      ]),

      const SizedBox(height: 20),

      // Image preview
      if (_image != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(children: [
            Image.file(_image!, width: double.infinity,
                height: 280, fit: BoxFit.cover),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _image = null),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: AppColors.surface, size: 16),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],

      // Placeholder when no image
      if (_image == null)
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline, width: 1.5),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.document_scanner_outlined,
                  size: 48, color: AppColors.textDisabled),
              SizedBox(height: 12),
              Text('Capture or select a document image',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              SizedBox(height: 4),
              Text('Supports JPG, PNG — physical documents, court orders, notices',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
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
          onPressed: (_image == null || _scanning) ? null : _extract,
          icon: _scanning
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface))
              : const Icon(Icons.document_scanner_outlined),
          label: Text(_scanning ? 'Extracting text...' : 'Extract Text'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      const SizedBox(height: 32),
    ]),
  );

  Widget _captureBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color,
                fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      );

  Widget _buildResult() => Column(children: [
    // Stats bar
    Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _stat('Words', '$_wordCount', AppColors.secondary),
        _statDivider(),
        _stat('Pages', '$_pageCount', AppColors.info),
        _statDivider(),
        _stat('Confidence', '${_confidence.toStringAsFixed(0)}%',
            _confidence >= 80 ? AppColors.success : AppColors.warning),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _text!));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Text copied to clipboard'),
              behavior: SnackBarBehavior.floating,
            ));
          },
          icon: const Icon(Icons.copy, size: 15),
          label: const Text('Copy'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ]),
    ),

    // Extracted text
    Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.sm,
        ),
        child: _text!.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No text could be extracted from this image.\n'
                    'Try a clearer image with better lighting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
              ))
            : SelectableText(_text!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.75,
                  color: AppColors.primaryLight,
                )),
      ),
    )),
  ]);

  Widget _stat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
    ],
  );

  Widget _statDivider() => Container(
    height: 28, width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: AppColors.outline,
  );
}
