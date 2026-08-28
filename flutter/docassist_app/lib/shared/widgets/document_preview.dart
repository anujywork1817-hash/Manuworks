import 'package:flutter/material.dart';

/// Renders AI-generated text as a simulated printed/Word-style page instead
/// of a plain chat-style paragraph blob: a white "sheet" with page margins,
/// a serif body font, and simple structure parsing (headings, bullets,
/// numbered lines) so the output reads like an actual document.
///
/// Understands a minimal subset of markdown-ish conventions the backend's
/// AI responses already tend to use — "# " / "## " headings, "- " / "* "
/// bullets, "1. " numbered lines, and "**bold**" — without pulling in a
/// full markdown renderer, since the goal here is a document *look*, not
/// rich markdown fidelity.
class DocumentPreview extends StatelessWidget {
  final String title;
  final String content;

  const DocumentPreview({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final blocks = <Widget>[];
    List<String>? bulletGroup;
    // Consecutive plain lines are wrapped-text fragments of the SAME
    // paragraph, not separate paragraphs — only a blank line (or a
    // heading/bullet/numbered line) actually starts a new one. Buffering
    // and joining them is what makes justify look like a real paragraph
    // instead of a series of short, oddly-stretched single lines.
    final paragraphBuffer = <String>[];

    void flushBullets() {
      if (bulletGroup == null || bulletGroup!.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: bulletGroup!.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  ', style: TextStyle(fontFamily: 'serif', fontSize: 13)),
              Expanded(child: _RichLine(b, baseSize: 13, justify: true)),
            ]),
          )).toList(),
        ),
      ));
      bulletGroup = null;
    }

    void flushParagraph() {
      if (paragraphBuffer.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _RichLine(paragraphBuffer.join(' '), baseSize: 13.5, justify: true),
      ));
      paragraphBuffer.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        flushBullets();
        flushParagraph();
        blocks.add(const SizedBox(height: 8));
        continue;
      }
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('# ')) {
        flushBullets();
        flushParagraph();
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Text(trimmed.substring(2),
              style: const TextStyle(fontFamily: 'serif', fontSize: 19,
                  fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        ));
      } else if (trimmed.startsWith('## ')) {
        flushBullets();
        flushParagraph();
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(trimmed.substring(3),
              style: const TextStyle(fontFamily: 'serif', fontSize: 16,
                  fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        (bulletGroup ??= []).add(trimmed.substring(2));
      } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        flushBullets();
        flushParagraph();
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _RichLine(trimmed, baseSize: 13.5, justify: true),
        ));
      } else {
        flushBullets();
        paragraphBuffer.add(trimmed);
      }
    }
    flushBullets();
    flushParagraph();

    // SelectionArea makes every Text/Text.rich inside selectable with the
    // mouse/touch and copyable via Ctrl+C or the system context menu —
    // without it, plain Text widgets render but can't be selected at all,
    // which is why the "click and drag to copy" behavior was missing.
    return SelectionArea(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontFamily: 'serif', fontSize: 20,
                  fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFD1D5DB)),
          ),
          ...blocks,
        ]),
      ),
    );
  }
}

/// Renders one line/paragraph with basic **bold** segments recognized.
class _RichLine extends StatelessWidget {
  final String text;
  final double baseSize;
  final bool justify;
  const _RichLine(this.text, {required this.baseSize, this.justify = false});

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
        fontFamily: 'serif', fontSize: baseSize, height: 1.65, color: const Color(0xFF1F2937));
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? baseStyle.copyWith(fontWeight: FontWeight.bold) : baseStyle,
      ));
    }
    return Text.rich(
      TextSpan(children: spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans),
      textAlign: justify ? TextAlign.justify : TextAlign.left,
    );
  }
}
