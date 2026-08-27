import 'dart:async';
import 'package:flutter/material.dart';

/// A Claude-style rotating status word shown during slow operations
/// (upload, OCR, AI processing). Cycles through a playful word list,
/// fading + sliding each transition, instead of a bare spinner/static text.
class FunLoadingWord extends StatefulWidget {
  final TextStyle? style;
  final Duration interval;

  const FunLoadingWord({
    super.key,
    this.style,
    this.interval = const Duration(milliseconds: 1400),
  });

  @override
  State<FunLoadingWord> createState() => _FunLoadingWordState();
}

class _FunLoadingWordState extends State<FunLoadingWord> {
  static const _words = [
    'Uploading',
    'Thinking',
    'Cooking',
    'Combobulating',
    'Percolating',
    'Marinating',
    'Noodling',
    'Conjuring',
    'Wrangling',
    'Churning',
    'Simmering',
    'Pondering',
    'Deciphering',
    'Untangling',
    'Brewing',
    'Flabbergasting',
    'Sorcering',
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _words.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: Text(
        '${_words[_index]}...',
        key: ValueKey<int>(_index),
        style: style,
      ),
    );
  }
}
