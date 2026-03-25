import 'package:flutter/services.dart';

/// Centralized haptic feedback system.
/// Provides consistent tactile feedback across the app.
class HapticHelper {
  /// Light tap — for navigation, toggles, selections
  static void lightTap() {
    HapticFeedback.lightImpact();
  }

  /// Medium tap — for confirmations, adding items
  static void mediumTap() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy tap — for destructive actions, important alerts
  static void heavyTap() {
    HapticFeedback.heavyImpact();
  }

  /// Selection click — for picker/scroll selections
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  /// Success vibration — double light tap
  static Future<void> success() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }

  /// Error vibration — single heavy tap
  static void error() {
    HapticFeedback.heavyImpact();
  }
}
