import 'package:flutter/material.dart';
import '../../core/services/clipboard_helper.dart';
import '../../core/services/document_export_service.dart';

/// Opens an explicit "how do you want to share this?" bottom sheet instead
/// of silently guessing — tapping Share used to either open a native share
/// sheet (only on platforms that support it) or, on most desktop browsers,
/// just silently download a PDF with no indication that's what happened.
/// This always asks, and every option here does something real: Copy Text
/// actually copies, WhatsApp/Gmail open pre-filled compose windows (they
/// can't carry file attachments — a hard browser limitation — so the PDF/
/// Word downloads are offered alongside for that).
Future<void> showShareOptionsSheet(
  BuildContext context, {
  required String title,
  required String content,
}) {
  return showModalBottomSheet(
    context: context,
    // Without this, the sheet attaches to the nested ShellRoute navigator
    // and renders BELOW the app's persistent bottom nav bar instead of
    // above it — clipping the last option(s) behind the nav bar.
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _ShareTile(
          icon: Icons.copy_rounded,
          color: const Color(0xFF16A34A),
          label: 'Copy text',
          subtitle: 'Copy the full content to your clipboard',
          onTap: () async {
            Navigator.pop(sheetContext);
            final ok = await copyToClipboard('$content\n\n${DocumentExportService.aiDisclaimer}');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Copied to clipboard' : 'Copy failed — try selecting the text instead'),
              ));
            }
          },
        ),
        _ShareTile(
          icon: Icons.forum_rounded,
          color: const Color(0xFF25D366),
          label: 'WhatsApp',
          subtitle: 'Send as a text message',
          onTap: () async {
            Navigator.pop(sheetContext);
            await DocumentExportService.shareViaWhatsApp(title: title, content: content);
          },
        ),
        _ShareTile(
          icon: Icons.mail_rounded,
          color: const Color(0xFFDC2626),
          label: 'Gmail',
          subtitle: 'Open a pre-filled email',
          onTap: () async {
            Navigator.pop(sheetContext);
            await DocumentExportService.shareViaGmail(title: title, content: content);
          },
        ),
        _ShareTile(
          icon: Icons.picture_as_pdf_rounded,
          color: const Color(0xFFD97706),
          label: 'Download PDF',
          onTap: () async {
            Navigator.pop(sheetContext);
            await DocumentExportService.exportReportToPdf(title: title, content: content);
          },
        ),
        _ShareTile(
          icon: Icons.description_rounded,
          color: const Color(0xFF2563EB),
          label: 'Download Word',
          onTap: () async {
            Navigator.pop(sheetContext);
            await DocumentExportService.exportReportToDocx(title: title, content: content);
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

class _ShareTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _ShareTile({
    required this.icon, required this.color, required this.label,
    this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 18),
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
    onTap: onTap,
  );
}
