import 'package:flutter/material.dart';
import 'atoms.dart';
import '../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Search Bar Molecule
// ---------------------------------------------------------------------------
class SearchBarWidget extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;

  const SearchBarWidget({
    Key? key,
    this.hintText = 'Search...',
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: AppTextInput(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondaryLight),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form Field (Label + Input) Molecule
// ---------------------------------------------------------------------------
class LabeledInputField extends StatelessWidget {
  final String label;
  final String hintText;
  final bool isPassword;

  const LabeledInputField({
    Key? key,
    required this.label,
    required this.hintText,
    this.isPassword = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AppTextInput(
          hintText: hintText,
          isPassword: isPassword,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat Card Molecule (For Dashboards)
// ---------------------------------------------------------------------------
class StatCardMolecule extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const StatCardMolecule({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                    color: AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
