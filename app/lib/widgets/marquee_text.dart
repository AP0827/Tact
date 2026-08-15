import 'package:flutter/material.dart';

/// Auto-scrolling marquee for long single-line text (track titles, etc.).
/// Static when the text fits; otherwise scrolls in a loop.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 6000),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  double _overflow = 0;
  bool _scroll = false;

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller?.dispose();
      _controller = null;
      _scroll = false;
      _overflow = 0;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _ensureScroll(double maxWidth) {
    if (_scroll || widget.text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final overflow = painter.width - maxWidth + 24;
    if (overflow > 0) {
      _overflow = overflow;
      _scroll = true;
      _controller = AnimationController(vsync: this, duration: widget.duration)
        ..repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_scroll) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _ensureScroll(constraints.maxWidth);
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }

    final controller = _controller!;
    return ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          // Hold briefly at each end, then scroll left.
          final travel = ((t + 0.15) % 1.0).clamp(0.0, 0.7) / 0.7;
          final offset = -_overflow * travel;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
            ),
          );
        },
      ),
    );
  }
}