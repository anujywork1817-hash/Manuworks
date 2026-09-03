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
      } else if (_isAllCapsHeading(trimmed)) {
        // Legal/contract drafts are deliberately written in plain text with
        // ALL-CAPS section headings ("1. DEFINITIONS", "WHEREAS", "IN
        // WITNESS WHEREOF") rather than markdown — recognizing that
        // convention directly is what makes a drafted agreement actually
        // look structured instead of one long justified paragraph.
        flushBullets();
        flushParagraph();
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Text(trimmed,
              style: const TextStyle(fontFamily: 'serif', fontSize: 14.5,
                  fontWeight: FontWeight.bold, color: Color(0xFF1F2937),
                  letterSpacing: 0.3)),
        ));
      } else if (RegExp(r'^\d+(\.\d+)*\.?\s').hasMatch(trimmed)) {
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
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF9CA3AF)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This document is AI-generated. Please refer to the original document before taking any further action.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic,
                      color: Color(0xFF9CA3AF), height: 1.4),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A short, all-uppercase line with no terminal sentence punctuation reads
/// as a section heading in a plain-text legal/contract draft — e.g.
/// "1. DEFINITIONS", "WHEREAS", "IN WITNESS WHEREOF", "FRANCHISE AGREEMENT".
/// Deliberately conservative (short, no sentence-ending period) so an
/// actual all-caps sentence in body text doesn't get misread as a heading.
bool _isAllCapsHeading(String line) {
  if (line.length < 3 || line.length > 90) return false;
  if (!RegExp(r'[A-Z]').hasMatch(line)) return false; // must contain a letter
  if (RegExp(r'[a-z]').hasMatch(line)) return false; // no lowercase letters
  if (line.endsWith('.') || line.endsWith(',')) return false; // not a full sentence
  final wordCount = line.trim().split(RegExp(r'\s+')).length;
  return wordCount <= 12;
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
