import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class ScannerScreen extends StatefulWidget {
  final bool returnMode;
  const ScannerScreen({super.key, this.returnMode = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.all],
  );

  bool _isScanned = false;
  bool _isLookingUp = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned || _isLookingUp) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    if (widget.returnMode) {
      if (!_isScanned) {
        setState(() => _isScanned = true);
        context.pop(code);
      }
      return;
    }

    setState(() {
      _isScanned = true;
      _isLookingUp = true;
    });

    _lookupProduct(code);
  }

  Future<void> _lookupProduct(String code) async {
    try {
      final supabase = Supabase.instance.client;

      // Search by generated_sku or factory_barcode
      final result = await supabase
          .from('products')
          .select('id, name')
          .or('generated_sku.eq.$code,factory_barcode.eq.$code')
          .maybeSingle();

      if (!mounted) return;

      if (result != null) {
        // Product found → navigate to detail page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم العثور على: ${result['name']}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 1),
          ),
        );

        // Small delay then navigate
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.push('/product/${result['id']}');
        }
      } else {
        // Unknown barcode → show error
        _showUnknownBarcodeDialog(code);
      }
    } catch (e) {
      debugPrint('Barcode lookup error: $e');
      if (mounted) {
        _showUnknownBarcodeDialog(code);
      }
    }
  }

  void _showUnknownBarcodeDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
        title: const Text('باركود مجهول'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'المنتج غير موجود في النظام',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, letterSpacing: 1),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isScanned = false;
                _isLookingUp = false;
              });
            },
            child: const Text('مسح مرة أخرى'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إدخال الباركود يدوياً'),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Roboto'),
          decoration: const InputDecoration(
            hintText: 'أدخل رقم الباركود...',
            prefixIcon: Icon(Icons.keyboard),
          ),
          keyboardType: TextInputType.text,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(ctx);
              setState(() {
                _isScanned = true;
                _isLookingUp = true;
              });
              _lookupProduct(value.trim());
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () {
                final code = textController.text.trim();
                Navigator.pop(ctx);
                if (code.isNotEmpty) {
                  if (widget.returnMode) {
                    context.pop(code);
                  } else {
                    setState(() {
                      _isScanned = true;
                      _isLookingUp = true;
                    });
                    _lookupProduct(code);
                  }
                }
              },
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }

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
          // Flash toggle
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: state.torchState == TorchState.on
                      ? Colors.amber
                      : Colors.white,
                ),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          // Camera flip
          IconButton(
            icon: const Icon(Icons.flip_camera_android, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview with error builder
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'خطأ في الكاميرا: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        error.errorDetails?.message ?? 'تعذر الوصول إلى الكاميرا. تأكد من منح الأذونات اللازمة.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _controller.start(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            },
            placeholderBuilder: (context, child) {
              return const Center(child: CircularProgressIndicator());
            },
          ),

          // Scan overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.8), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Container(
                  height: 2,
                  width: double.infinity,
                  color: Colors.redAccent.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),

          // Loading indicator during lookup
          if (_isLookingUp)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('جارٍ البحث عن المنتج...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),

          // Bottom panel
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
                  Text(
                    'سيتم البحث عن المنتج تلقائياً عند مسح الباركود',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showManualEntryDialog,
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
