import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A premium Glassmorphism card with press-to-scale animation,
/// backdrop blur, ghost borders, and ambient glow on hover.
class AnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? color;
  final double blur;
  final double opacity;

  const AnimatedGlassCard({
    Key? key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.all(0),
    this.borderRadius = 20.0,
    this.color,
    this.blur = 20.0,
    this.opacity = 0.7,
  }) : super(key: key);

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Obsidian Glass: Surface layering instead of borders
    final cardColor = widget.color ??
        (isDark
            ? AppColors.surfaceContainerHigh.withOpacity(widget.opacity)
            : AppColors.surfaceLight.withOpacity(widget.opacity == 1.0 ? 0.75 : widget.opacity)); // More transparent in light mode for blur

    // Ghost Border: subtle whisper boundary
    final borderColor = isDark
        ? AppColors.ghostBorder
        : AppColors.tertiary.withOpacity(0.1); // Subtly tinted border

    // Ambient shadow: Clean professional drop shadow
    final defaultShadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), // Clean, subtle gray
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            )
          ];

    // Hover glow: primary-tinted expansion
    final hoverShadows = isDark
        ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            )
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // Slightly stronger neutral shadow
              blurRadius: 25,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            )
          ];

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            cardColor.withOpacity(cardColor.opacity * 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: _isHovering ? hoverShadows : defaultShadows,
      ),
      child: widget.child,
    );

    // Apply backdrop blur for glassmorphism
    if (widget.blur > 0 && isDark) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: cardContent,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _onTapDown : null,
        onTapUp: widget.onTap != null ? _onTapUp : null,
        onTapCancel: widget.onTap != null ? _onTapCancel : null,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: Padding(
            padding: widget.margin,
            child: cardContent,
          ),
        ),
      ),
    );
  }
}
