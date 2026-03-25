import 'package:flutter/material.dart';

/// Obsidian Glass Design System — Color Tokens
/// Based on the "Luminous Ledger" aesthetic from Stitch.
class AppColors {
  AppColors._();

  // ─── Primary Brand ───
  static const Color primary = Color(0xFF3B82F6);       // Electric Blue
  static const Color primaryDim = Color(0xFF699CFF);
  static const Color primaryContainer = Color(0xFF6E9FFF);
  static const Color primaryVariant = Color(0xFF2563EB); // Legacy alias

  // ─── Secondary (Emerald) ───
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryBright = Color(0xFF69F6B8);

  // ─── Tertiary (Vivid Purple) ───
  static const Color tertiary = Color(0xFFA855F7);
  static const Color tertiaryBright = Color(0xFFC180FF);

  // ─── Surface / Background Layers (Obsidian Palette) ───
  static const Color backgroundDark = Color(0xFF060E20);   // The Void
  static const Color surfaceDark = Color(0xFF0F1930);       // Surface Container
  static const Color surfaceContainerLow = Color(0xFF091328);
  static const Color surfaceContainerHigh = Color(0xFF141F38);
  static const Color surfaceContainerHighest = Color(0xFF192540);
  static const Color surfaceBright = Color(0xFF1F2B49);
  static const Color surfaceVariant = Color(0xFF192540);    // Glass base

  // ─── Light mode surfaces ───
  static const Color backgroundLight = Color(0xFFFAFAFF);
  static const Color surfaceLight = Colors.white;

  // ─── Status Colors ───
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFFF716C);           // Sunset Orange/Red
  static const Color errorContainer = Color(0xFF9F0519);
  static const Color warning = Color(0xFFF59E0B);

  // ─── Text (Obsidian Tokens) ───
  static const Color textPrimaryDark = Color(0xFFDEE5FF);
  static const Color textSecondaryDark = Color(0xFFA3AAC4);
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // ─── Borders / Outlines (Ghost Border Rule) ───
  static const Color outline = Color(0xFF6D758C);
  static const Color outlineVariant = Color(0xFF40485D);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF40485D);

  // ─── Glass Constants ───
  static const double glassBlur = 20.0;
  static Color get glassBackground => surfaceVariant.withOpacity(0.4);
  static Color get ghostBorder => outline.withOpacity(0.15);
}
