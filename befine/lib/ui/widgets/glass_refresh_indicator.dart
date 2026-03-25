import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Custom refresh indicator with glass styling.
/// Wraps a scrollable widget (e.g., ListView, SingleChildScrollView).
class GlassRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const GlassRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: isDark
          ? AppColors.surfaceContainerHigh
          : Colors.white,
      strokeWidth: 2.5,
      displacement: 60,
      child: child,
    );
  }
}
