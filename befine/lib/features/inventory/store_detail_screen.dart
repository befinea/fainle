import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
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
  Map<String, dynamic>? _storeDetails;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchStoreDetails();
  }

  Future<void> _fetchStoreDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      _companyId = profile['company_id'] as String;

      final data = await _supabase.from('locations').select('*').eq('id', widget.storeId).single();
      if (mounted) setState(() => _storeDetails = data);
    } catch (e) {
      debugPrint('Error fetching store details: $e');
    }
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

                      // Auto-generate SKU for barcode
                      final ts = DateTime.now().millisecondsSinceEpoch % 1000000;
                      final sku = 'BF-${ts.toString().padLeft(6, '0')}';
                      await _supabase.from('products').update({'generated_sku': sku}).eq('id', productRes['id']);

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

  void _showEditStoreDialog(Map<String, dynamic> store) {
    final nameCtrl = TextEditingController(text: store['name'] as String? ?? '');
    String? selectedWarehouseId = store['parent_id'] as String?;
    bool isLoading = true;
    List<Map<String, dynamic>> warehousesInfo = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isLoading && warehousesInfo.isEmpty) {
            _supabase.from('locations')
              .select('id, name, address, max_stores, company_id')
              .eq('type', 'warehouse')
              .or('company_id.eq.$_companyId,company_id.eq.00000000-0000-0000-0000-000000000001')
              .then((whData) async {
              final storeData = await _supabase.from('locations').select('parent_id').eq('company_id', _companyId!).eq('type', 'store').not('parent_id', 'is', 'null');
              
              final Map<String, int> warehouseCounts = {};
              for (var s in List<Map<String, dynamic>>.from(storeData)) {
                final pid = s['parent_id'] as String;
                warehouseCounts[pid] = (warehouseCounts[pid] ?? 0) + 1;
              }

              final whList = List<Map<String, dynamic>>.from(whData);
              for (var wh in whList) {
                final max = wh['max_stores'] as int? ?? 5;
                final reserved = warehouseCounts[wh['id'] as String] ?? 0;
                wh['reserved'] = reserved;
                wh['available'] = max - reserved;
              }

              if (mounted) {
                setDialogState(() {
                  warehousesInfo = whList;
                  isLoading = false;
                });
              }
            }).catchError((e) {
              if (mounted) setDialogState(() => isLoading = false);
            });
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: AnimatedGlassCard(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 48, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text('تعديل تفاصيل المتجر', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'اسم المتجر', prefixIcon: const Icon(Icons.store_rounded),
                        filled: true, fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<String>(
                        value: selectedWarehouseId,
                        isExpanded: true,
                        itemHeight: 70,
                        decoration: InputDecoration(
                          labelText: 'المخزن التابع له',
                          prefixIcon: const Icon(Icons.warehouse_rounded),
                          filled: true, fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: warehousesInfo.map((wh) {
                          final whCompanyId = wh['company_id'] as String?;
                          final isGlobal = whCompanyId != _companyId;
                          final name = (wh['name'] as String) + (isGlobal ? ' (مخزن رئيسي)' : '');
                          final isCurrent = wh['id'] == store['parent_id'];
                          final available = wh['available'] as int? ?? 0;
                          final isFull = available <= 0 && !isCurrent;

                          return DropdownMenuItem<String>(
                            value: wh['id'] as String,
                            enabled: !isFull,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isFull ? Colors.grey : (isGlobal ? Colors.orange : null))),
                                const SizedBox(height: 2),
                                Text(
                                  isCurrent ? 'المخزن الحالي' : 'متاح: $available',
                                  style: TextStyle(fontSize: 11, color: isFull ? Colors.red.shade400 : Colors.grey.shade500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        selectedItemBuilder: (context) => warehousesInfo.map((wh) {
                          final whCompanyId = wh['company_id'] as String?;
                          final isGlobal = whCompanyId != _companyId;
                          final name = (wh['name'] as String) + (isGlobal ? ' (مخزن رئيسي)' : '');
                          return Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold));
                        }).toList(),
                        onChanged: (v) => setDialogState(() => selectedWarehouseId = v),
                      ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                          style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1)),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('تأكيد الحذف'),
                                content: const Text('هل أنت متأكد من حذف المتجر؟ لا يمكن التراجع.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('حذف'),
                                  ),
                                ]
                              )
                            );
                            if (confirm == true) {
                              Navigator.pop(ctx);
                              _deleteStore(store['id'] as String);
                            }
                          },
                        ),
                        Row(
                          children: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              onPressed: () {
                                if (nameCtrl.text.trim().isNotEmpty && selectedWarehouseId != null) {
                                  _updateStore(store['id'] as String, nameCtrl.text.trim(), selectedWarehouseId!);
                                  Navigator.pop(ctx);
                                }
                              },
                              child: const Text('حفظ'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateStore(String id, String name, String parentId) async {
    try {
      await _supabase.from('locations').update({
        'name': name,
        'parent_id': parentId,
      }).eq('id', id);
      _fetchStoreDetails();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _deleteStore(String id) async {
    try {
      await _supabase.from('locations').delete().eq('id', id);
      if (mounted) context.pop(); // Go back
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: AppColors.error));
    }
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
                title: Text('متجر: ${_storeDetails?['name'] ?? widget.storeName}', style: theme.textTheme.titleMedium),
                floating: true,
                actions: [
                  IconButton(
                    tooltip: 'تعديل المتجر',
                    icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                    onPressed: () {
                      if (_storeDetails != null) {
                        _showEditStoreDialog(_storeDetails!);
                      }
                    },
                  ),
                  IconButton(tooltip: 'إضافة منتج', icon: const Icon(Icons.add_circle_outline), onPressed: _showAddProductDialog),
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
                            onTap: () {
                              context.push(
                                '/product/${product['id']}',
                                extra: {'storeId': widget.storeId},
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 54, height: 54,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 28),
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
