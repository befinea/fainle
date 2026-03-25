import 'package:flutter/material.dart';

/// Animated counter that counts up from 0 to the target value.
/// Perfect for stat cards in Dashboard.
class AnimatedCounter extends StatelessWidget {
  final String value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 600),
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    // Try to parse the value as a number
    final numericValue = double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));

    if (numericValue == null) {
      // Not a number, just display it
      return Text('$prefix$value$suffix', style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: numericValue),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        String displayValue;
        if (numericValue == numericValue.roundToDouble()) {
          // Integer
          displayValue = animatedValue.toInt().toString();
        } else {
          // Decimal (2 places)
          displayValue = animatedValue.toStringAsFixed(2);
        }
        // Add commas for thousands
        displayValue = _formatWithCommas(displayValue);
        return Text('$prefix$displayValue$suffix', style: style);
      },
    );
  }

  String _formatWithCommas(String value) {
    final parts = value.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      buffer.write(intPart[i]);
      count++;
      if (count % 3 == 0 && i > 0 && intPart[i] != '-') {
        buffer.write(',');
      }
    }
    String result = buffer.toString().split('').reversed.join();
    if (parts.length > 1) {
      result += '.${parts[1]}';
    }
    return result;
  }
}
