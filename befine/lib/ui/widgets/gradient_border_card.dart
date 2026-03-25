import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// A card with an animated gradient border.
/// Looks premium and modern, similar to GitHub Copilot / ChatGPT Plus styling.
class GradientBorderCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final List<Color>? gradientColors;
  final Duration animationDuration;

  const GradientBorderCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.borderWidth = 2,
    this.padding = const EdgeInsets.all(20),
    this.gradientColors,
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  State<GradientBorderCard> createState() => _GradientBorderCardState();
}

class _GradientBorderCardState extends State<GradientBorderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = widget.gradientColors ??
        [
          AppColors.primary,
          AppColors.tertiary,
          AppColors.secondary,
          AppColors.primary,
        ];

    final bgColor = isDark
        ? AppColors.surfaceContainerHigh
        : Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              center: Alignment.center,
              startAngle: 0,
              endAngle: 6.28, // 2 * pi
              transform: GradientRotation(_controller.value * 6.28),
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.tertiary.withOpacity(isDark ? 0.15 : 0.08),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            margin: EdgeInsets.all(widget.borderWidth),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius - widget.borderWidth),
            ),
            padding: widget.padding,
            child: widget.child,
          ),
        );
      },
    );
  }
}
