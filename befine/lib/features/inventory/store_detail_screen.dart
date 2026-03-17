import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreDetailScreen({super.key, required this.storeId, required this.storeName});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      // 1. Fetch stock levels for this specific store
      final stockData = await _supabase
          .from('stock_levels')
          .select('quantity, products(*)')
          .eq('location_id', widget.storeId);

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(stockData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddProductDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    String? selectedCategoryId;

    // Fetch categories for the dropdown
    List<Map<String, dynamic>> categories = [];
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
        final data = await _supabase.from('categories').select().eq('company_id', profile['company_id']).order('name');
        categories = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('إضافة منتج جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج')),
                    const SizedBox(height: 12),
                    TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع')),
                    const SizedBox(height: 12),
                    TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الأولية')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'الصنف (اختياري)'),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('بدون صنف')),
                        ...categories.map((cat) => DropdownMenuItem<String>(
                          value: cat['id'] as String,
                          child: Text(cat['name'] as String),
                        )),
                      ],
                      onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    Navigator.pop(ctx);
                    
                    try {
                      final user = _supabase.auth.currentUser;
                      final profile = await _supabase.from('profiles').select('company_id').eq('id', user!.id).single();
                      
                      final productData = <String, dynamic>{
                        'company_id': profile['company_id'],
                        'name': nameCtrl.text.trim(),
                        'sale_price': double.tryParse(priceCtrl.text) ?? 0,
                      };
                      if (selectedCategoryId != null) {
                        productData['category_id'] = selectedCategoryId;
                      }

                      final productRes = await _supabase.from('products').insert(productData).select().single();

                      await _supabase.from('stock_levels').insert({
                        'location_id': widget.storeId,
                        'product_id': productRes['id'],
                        'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                      });

                      _fetchProducts();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    }
                  },
                  child: const Text('إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.background.withOpacity(0.9),
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                title: Text('متجر: ${widget.storeName}', style: theme.textTheme.titleMedium),
                floating: true,
                actions: [
                  IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showAddProductDialog),
                ],
              ),
              if (_isLoading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_products.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('لا توجد منتجات في هذا المتجر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _showAddProductDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة منتج'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final item = _products[i];
                        final product = item['products'] as Map<String, dynamic>;
                        final quantity = item['quantity'] as int;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AnimatedGlassCard(
                            padding: const EdgeInsets.all(16),
                            onTap: () {},
                            child: Row(
                              children: [
                                Container(
                                  width: 54, height: 54,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.grey.shade200, Colors.grey.shade100],
                                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(Icons.inventory_2, color: AppColors.primary.withOpacity(0.5), size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(product['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                      Text('السعر: ${product['sale_price']} د', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$quantity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: quantity < 5 ? AppColors.error : AppColors.success,
                                      ),
                                    ),
                                    Text('في المخزن', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _products.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
