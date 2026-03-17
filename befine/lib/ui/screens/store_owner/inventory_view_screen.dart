import 'package:flutter/material.dart';
import '../../widgets/atoms.dart';
import '../../../core/theme/app_colors.dart';

class InventoryViewScreen extends StatefulWidget {
  const InventoryViewScreen({Key? key}) : super(key: key);

  @override
  State<InventoryViewScreen> createState() => _InventoryViewScreenState();
}

class _InventoryViewScreenState extends State<InventoryViewScreen> {
  bool _isSuccessOverlay = false;
  bool _isErrorOverlay = false;
  final TextEditingController _barcodeController = TextEditingController();

  void _simulateScan(bool success) {
    setState(() {
      if (success) {
        _isSuccessOverlay = true;
        _barcodeController.text = '192837465012';
      } else {
        _isErrorOverlay = true;
        _barcodeController.text = 'INVALID_CODE';
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isSuccessOverlay = false;
          _isErrorOverlay = false;
          _barcodeController.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark mode for scanner focus
      appBar: AppBar(
        title: const Text('High-Speed Inventory Scanner', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Simulated Camera View
          Positioned.fill(
            child: Container(
              color: Colors.grey[900],
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 120, color: Colors.white24),
                    SizedBox(height: 16),
                    AppText('Camera View Active', color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),
          
          // Scanner Reticle
          Center(
            child: Container(
              width: 300,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        height: 2,
                        width: double.infinity,
                        color: Colors.redAccent.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Feedback Overlays (Green = Success, Red = Error)
          if (_isSuccessOverlay)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0,
                child: Container(
                  color: AppColors.success.withOpacity(0.4),
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.white, size: 100),
                  ),
                ),
              ),
            ),
            
          if (_isErrorOverlay)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0,
                child: Container(
                  color: AppColors.error.withOpacity(0.4),
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 100),
                  ),
                ),
              ),
            ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextInput(
                    hintText: 'Manual Barcode Entry...',
                    controller: _barcodeController,
                    prefixIcon: const Icon(Icons.barcode_reader),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'Simulate Success',
                          variant: ButtonVariant.primary,
                          onPressed: () => _simulateScan(true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomButton(
                          label: 'Simulate Error',
                          variant: ButtonVariant.outline,
                          onPressed: () => _simulateScan(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
