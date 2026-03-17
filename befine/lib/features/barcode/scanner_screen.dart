import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('مسح الباركود'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          Container(color: Colors.grey.shade900),
          Center(
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Container(height: 2, width: double.infinity, color: Colors.redAccent.withValues(alpha: 0.6)),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 40, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text('وجّه الكاميرا نحو الباركود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('يدعم باركودات المصنع والباركودات المُولَّدة من النظام', style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم العثور على المنتج: منتج أ (متجر 1، المخزن الرئيسي)')),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.keyboard),
                      label: const Text('إدخال الباركود يدوياً'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
