import 'package:flutter/material.dart';

class AnimatedNumber extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int decimals;
  final TextStyle? style;
  final bool useCommas;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 1,
    this.style,
    this.useCommas = false,
  });

  @override
  State<AnimatedNumber> createState() => AnimatedNumberState();
}

class AnimatedNumberState extends State<AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _started = false;
  int _retryCount = 0;

  Duration get _effectiveDuration {
    final v = widget.value.abs();
    if (v <= 10) return const Duration(milliseconds: 2000);
    if (v <= 100) return const Duration(milliseconds: 1800);
    if (v <= 1000) return const Duration(milliseconds: 1500);
    return const Duration(milliseconds: 1200);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _effectiveDuration);
    _animation = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryCheckVisibility());
  }

  void _tryCheckVisibility() {
    if (_started || !mounted) return;
    checkVisibility();
    // Retry a few times if not visible yet (layout might not be ready)
    if (!_started && _retryCount < 5) {
      _retryCount++;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _tryCheckVisibility();
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.duration = _effectiveDuration;
      _animation = Tween<double>(begin: _animation.value, end: widget.value)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
      _started = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void checkVisibility() {
    if (_started || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final pos = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size.height;

    if (pos.dy >= 0 && pos.dy < screen + 50) {
      _started = true;
      _controller.forward();
    }
  }

  String _format(double val) {
    if (widget.useCommas) {
      final parts = val.toStringAsFixed(widget.decimals).split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      return widget.decimals > 0 ? '$intPart.${parts[1]}' : intPart;
    }
    return val.toStringAsFixed(widget.decimals);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Text(
          '${widget.prefix}${_format(_animation.value)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
