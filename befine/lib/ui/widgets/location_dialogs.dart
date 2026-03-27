import 'package:flutter/material.dart';
import 'dart:ui';
import 'animated_glass_card.dart';

Future<void> showAddLocationDialog(
  BuildContext context, {
  required Function(String name, String address, int? maxStores) onSubmit,
}) async {
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final maxStoresCtrl = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (ctx) => _AddLocationDialog(
      nameCtrl: nameCtrl,
      addressCtrl: addressCtrl,
      maxStoresCtrl: maxStoresCtrl,
      onSubmit: () {
        if (nameCtrl.text.trim().isNotEmpty) {
          final maxStores = int.tryParse(maxStoresCtrl.text.trim());
          onSubmit(nameCtrl.text.trim(), addressCtrl.text.trim(), maxStores);
          Navigator.pop(ctx);
        }
      },
      onCancel: () => Navigator.pop(ctx),
    ),
  );
}

Future<void> showEditLocationDialog(
  BuildContext context, {
  required Map<String, dynamic> location,
  required Function(String name, String address, int? maxStores) onSave,
  required VoidCallback onDelete,
}) async {
  final nameCtrl = TextEditingController(text: location['name'] as String? ?? '');
  final addressCtrl = TextEditingController(text: location['address'] as String? ?? '');
  final maxStoresCtrl = TextEditingController(text: location['max_stores']?.toString() ?? '');

  return showDialog<void>(
    context: context,
    builder: (ctx) => _EditLocationDialog(
      nameCtrl: nameCtrl,
      addressCtrl: addressCtrl,
      maxStoresCtrl: maxStoresCtrl,
      onSave: () {
        if (nameCtrl.text.trim().isNotEmpty) {
          final maxStores = int.tryParse(maxStoresCtrl.text.trim());
          onSave(nameCtrl.text.trim(), addressCtrl.text.trim(), maxStores);
          Navigator.pop(ctx);
        }
      },
      onDelete: () {
        onDelete();
        Navigator.pop(ctx);
      },
      onCancel: () => Navigator.pop(ctx),
    ),
  );
}

// ----------------------------------------------------------------------
// Add Location Dialog
// ----------------------------------------------------------------------
class _AddLocationDialog extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController maxStoresCtrl;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _AddLocationDialog({
    required this.nameCtrl,
    required this.addressCtrl,
    required this.maxStoresCtrl,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final theme = Theme.of(context);

    // Dialog outer container
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 800 : 400),
        child: AnimatedGlassCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'إضافة مخزن جديد',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    if (isDesktop) _buildDesktopForm() else _buildMobileForm(),
                    const SizedBox(height: 32),
                    _buildActions(isDesktop, theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopForm() {
    return Row(
      children: [
        Expanded(child: _GlassInput(controller: nameCtrl, label: 'اسم المخزن', icon: Icons.store_rounded)),
        const SizedBox(width: 16),
        Expanded(child: _GlassInput(controller: addressCtrl, label: 'العنوان', icon: Icons.location_on_rounded)),
        const SizedBox(width: 16),
        Expanded(
            child: _GlassInput(
                controller: maxStoresCtrl,
                label: 'الحد الأقصى (اختياري)',
                icon: Icons.numbers_rounded,
                isNumber: true)),
      ],
    );
  }

  Widget _buildMobileForm() {
    return Column(
      children: [
        _GlassInput(controller: nameCtrl, label: 'اسم المخزن', icon: Icons.store_rounded),
        const SizedBox(height: 16),
        _GlassInput(controller: addressCtrl, label: 'العنوان', icon: Icons.location_on_rounded),
        const SizedBox(height: 16),
        _GlassInput(
            controller: maxStoresCtrl,
            label: 'الحد الأقصى (اختياري)',
            icon: Icons.numbers_rounded,
            isNumber: true),
      ],
    );
  }

  Widget _buildActions(bool isDesktop, ThemeData theme) {
    return Row(
      mainAxisAlignment: isDesktop ? MainAxisAlignment.center : MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: theme.colorScheme.primary,
          ),
          child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (isDesktop) const SizedBox(width: 16),
        ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 8,
            shadowColor: theme.colorScheme.primary.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// Edit Location Dialog
// ----------------------------------------------------------------------
class _EditLocationDialog extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController maxStoresCtrl;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _EditLocationDialog({
    required this.nameCtrl,
    required this.addressCtrl,
    required this.maxStoresCtrl,
    required this.onSave,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 800 : 400),
        child: AnimatedGlassCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_rounded, color: theme.colorScheme.primary, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'تعديل تفاصيل المخزن',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    if (isDesktop) _buildDesktopForm() else _buildMobileForm(),
                    const SizedBox(height: 32),
                    _buildActions(isDesktop, theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopForm() {
    return Row(
      children: [
        Expanded(child: _GlassInput(controller: nameCtrl, label: 'اسم المخزن', icon: Icons.store_rounded)),
        const SizedBox(width: 16),
        Expanded(child: _GlassInput(controller: addressCtrl, label: 'العنوان', icon: Icons.location_on_rounded)),
        const SizedBox(width: 16),
        Expanded(
            child: _GlassInput(
                controller: maxStoresCtrl,
                label: 'الحد الأقصى',
                icon: Icons.numbers_rounded,
                isNumber: true)),
      ],
    );
  }

  Widget _buildMobileForm() {
    return Column(
      children: [
        _GlassInput(controller: nameCtrl, label: 'اسم المخزن', icon: Icons.store_rounded),
        const SizedBox(height: 16),
        _GlassInput(controller: addressCtrl, label: 'العنوان', icon: Icons.location_on_rounded),
        const SizedBox(height: 16),
        _GlassInput(
            controller: maxStoresCtrl, label: 'الحد الأقصى', icon: Icons.numbers_rounded, isNumber: true),
      ],
    );
  }

  Widget _buildActions(bool isDesktop, ThemeData theme) {
    return Row(
      mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 8,
            shadowColor: theme.colorScheme.primary.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (isDesktop) const SizedBox(width: 16),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: theme.colorScheme.primary,
          ),
          child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (isDesktop) const Spacer(),
        IconButton(
          onPressed: onDelete,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.error.withOpacity(0.1),
            foregroundColor: theme.colorScheme.error,
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'حذف',
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// Reusable Glass Input
// ----------------------------------------------------------------------
class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumber;

  const _GlassInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2), // Dark, slightly transparent background
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
