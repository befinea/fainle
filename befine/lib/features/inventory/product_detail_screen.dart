import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barcode/barcode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../ui/widgets/glass_toast.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final String? storeId; // optional: if coming from a store context

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.storeId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _product;
  int _quantity = 0;
  String? _categoryName;
  bool _showBarcode = false;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    try {
      final product = await _supabase
          .from('products')
          .select('*, categories(name)')
          .eq('id', widget.productId)
          .single();

      // Fetch quantity if storeId is provided
      int qty = 0;
      if (widget.storeId != null) {
        final stock = await _supabase
            .from('stock_levels')
            .select('quantity')
            .eq('product_id', widget.productId)
            .eq('location_id', widget.storeId!)
            .maybeSingle();
        qty = (stock?['quantity'] as int?) ?? 0;
      } else {
        // Sum all stock levels
        final stocks = await _supabase
            .from('stock_levels')
            .select('quantity')
            .eq('product_id', widget.productId);
        for (final s in stocks) {
          qty += (s['quantity'] as int?) ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _product = product;
          _quantity = qty;
          _categoryName = product['categories']?['name'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching product: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditDialog() {
    if (_product == null) return;
    final nameCtrl = TextEditingController(text: _product!['name']);
    final priceCtrl = TextEditingController(text: _product!['sale_price']?.toString() ?? '0');
    final qtyCtrl = TextEditingController(text: _quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل المنتج'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المنتج',
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سعر البيع',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.storeId != null)
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateProduct(
                name: nameCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text) ?? 0,
                quantity: int.tryParse(qtyCtrl.text) ?? _quantity,
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProduct({
    required String name,
    required double price,
    required int quantity,
  }) async {
    try {
      await _supabase.from('products').update({
        'name': name,
        'sale_price': price,
      }).eq('id', widget.productId);

      if (widget.storeId != null) {
        await _supabase.from('stock_levels').update({
          'quantity': quantity,
        }).eq('product_id', widget.productId).eq('location_id', widget.storeId!);
      }

      _fetchProduct();
      if (mounted) {
        HapticHelper.success();
        GlassToast.show(context, 'تم تحديث المنتج بنجاح ✓', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        HapticHelper.error();
        GlassToast.show(context, 'خطأ في التحديث: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف المنتج'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('products').delete().eq('id', widget.productId);
        if (mounted) {
          HapticHelper.success();
          GlassToast.show(context, 'تم حذف المنتج بنجاح', type: ToastType.success);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          HapticHelper.error();
          GlassToast.show(context, 'خطأ في الحذف: $e', type: ToastType.error);
        }
      }
    }
  }

  Future<void> _generateSku() async {
    if (_product == null) return;
    if (_product!['generated_sku'] != null && _product!['generated_sku'].toString().isNotEmpty) {
      setState(() => _showBarcode = true);
      return;
    }

    try {
      // Generate unique SKU: BF-XXXXXX (timestamp based)
      final timestamp = DateTime.now().millisecondsSinceEpoch % 1000000;
      final sku = 'BF-${timestamp.toString().padLeft(6, '0')}';

      await _supabase.from('products').update({'generated_sku': sku}).eq('id', widget.productId);
      await _fetchProduct();
      setState(() => _showBarcode = true);

      if (mounted) {
        HapticHelper.success();
        GlassToast.show(context, 'تم إنتاج الباركود: $sku', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        HapticHelper.error();
        GlassToast.show(context, 'خطأ: $e', type: ToastType.error);
      }
    }
  }

  Color _getCategoryColor() {
    if (_categoryName == null || _categoryName!.isEmpty) return AppColors.primary;
    // Simple hash to generate a consistent color for a specific category
    int hash = 0;
    for (int i = 0; i < _categoryName!.length; i++) {
      hash = _categoryName!.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = (hash % 360).abs().toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.7, 0.9).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المنتج')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المنتج')),
        body: const Center(child: Text('المنتج غير موجود')),
      );
    }

    final sku = _product!['generated_sku']?.toString() ?? '';
    final hasBarcode = sku.isNotEmpty;

    final dynamicColor = _getCategoryColor();
    final dynamicTheme = theme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: dynamicColor,
        brightness: theme.brightness,
      ),
    );

    return Theme(
      data: dynamicTheme,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                dynamicTheme.colorScheme.surface,
                dynamicTheme.colorScheme.surface,
                dynamicColor.withOpacity(0.05),
              ],
            ),
          ),
          child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                title: Text('تفاصيل المنتج', style: theme.textTheme.titleMedium),
                floating: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _showEditDialog,
                    tooltip: 'تعديل',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: _deleteProduct,
                    tooltip: 'حذف',
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Icon & Name
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                dynamicColor.withOpacity(0.2),
                                dynamicColor.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(Icons.inventory_2_rounded, size: 48, color: dynamicColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _product!['name'] ?? 'بدون اسم',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_categoryName != null) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: dynamicColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_categoryName!, style: TextStyle(color: dynamicColor, fontSize: 13)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Info Cards
                      _buildInfoRow(Icons.attach_money_rounded, 'سعر البيع', '${_product!['sale_price'] ?? 0} د', AppColors.success),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.money_off_rounded, 'سعر الشراء', '${_product!['purchase_price'] ?? 0} د', Colors.orange),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.inventory_rounded,
                        'الكمية المتوفرة',
                        '$_quantity',
                        _quantity < 5 ? AppColors.error : AppColors.success,
                      ),
                      if (hasBarcode) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.qr_code_rounded, 'الرقم التسلسلي', sku, dynamicColor, dynamicTheme),
                      ],

                      const SizedBox(height: 28),

                      // Generate Barcode Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _generateSku,
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: Text(hasBarcode ? 'عرض الباركود' : 'إنتاج باركود'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dynamicColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),

                      // Barcode Display
                      if (_showBarcode && hasBarcode) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text('باركود المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                              const SizedBox(height: 16),
                              // Draw barcode using CustomPaint
                              CustomPaint(
                                size: const Size(280, 100),
                                painter: BarcodePainter(sku),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                sku,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                  fontFamily: 'Roboto',
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color, [ThemeData? localTheme]) {
    final theme = localTheme ?? Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ─── Barcode Painter ───────────────────────────────────────

class BarcodePainter extends CustomPainter {
  final String data;

  BarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final bc = Barcode.code128();
      // Generate the barcode geometry
      final elements = bc.make(data, width: size.width, height: size.height, drawText: false);

      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      for (var element in elements) {
        if (element is BarcodeBar) {
          if (element.black) {
            canvas.drawRect(
              Rect.fromLTWH(element.left, element.top, element.width, element.height),
              paint,
            );
          }
        }
      }
    } catch (e) {
      // Draw placeholder if barcode generation fails
      final textPainter = TextPainter(
        text: TextSpan(text: data, style: const TextStyle(color: Colors.black, fontSize: 14)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, size.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
