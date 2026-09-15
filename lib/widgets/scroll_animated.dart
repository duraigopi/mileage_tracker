import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ScrollAnimated extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const ScrollAnimated({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<ScrollAnimated> createState() => ScrollAnimatedState();
}

class ScrollAnimatedState extends State<ScrollAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_triggered && mounted) {
        _triggered = true;
        Future.delayed(widget.delay, () {
          if (mounted) _controller.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Keep for compatibility but no longer needed for scroll detection
  void checkVisibility() {}

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - _controller.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
