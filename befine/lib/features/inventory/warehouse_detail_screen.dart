import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/application/auth_service.dart';

class WarehouseDetailScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  final String warehouseName;

  const WarehouseDetailScreen({super.key, required this.warehouseId, required this.warehouseName});

  @override
  ConsumerState<WarehouseDetailScreen> createState() => _WarehouseDetailScreenState();
}

class _WarehouseDetailScreenState extends ConsumerState<WarehouseDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _stores = [];
  int? _maxStores;
  List<Map<String, dynamic>> _allCategories = [];
  Map<String, dynamic>? _warehouseDetails;

  @override
  void initState() {
    super.initState();
    _fetchStores();
    _fetchWarehouseDetails();
    _fetchCategories();
  }

  Future<void> _fetchWarehouseDetails() async {
    try {
      final data = await _supabase.from('locations').select('*').eq('id', widget.warehouseId).single();
      if (mounted) {
        setState(() {
          _warehouseDetails = data;
          _maxStores = data['max_stores'] as int?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching warehouse details: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final data = await _supabase.from('categories').select().eq('company_id', profile['company_id']).order('name');
      if (mounted) setState(() => _allCategories = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _fetchStores() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('locations')
          .select()
          .eq('parent_id', widget.warehouseId)
          .eq('type', 'store')
          .order('created_at');

      if (mounted) {
        setState(() {
          _stores = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stores: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addStore(String name, List<String> categoryIds) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      
      final storeRes = await _supabase.from('locations').insert({
        'company_id': profile['company_id'],
        'name': name,
        'type': 'store',
        'parent_id': widget.warehouseId,
      }).select('id').single();

      // Save store categories
      if (categoryIds.isNotEmpty) {
        final rows = categoryIds.map((catId) => {
          'store_id': storeRes['id'],
          'category_id': catId,
        }).toList();
        await _supabase.from('store_categories').insert(rows);
      }

      _fetchStores();
    } catch (e) {
      debugPrint('Error adding store: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: AppColors.error));
      }
    }
  }

  void _showAddDialog() {
    // Check max_stores limit
    if (_maxStores != null && _stores.length >= _maxStores!) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم الوصول للحد الأقصى للمتاجر ($_maxStores متاجر)'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final nameCtrl = TextEditingController();
    final selectedCategoryIds = <String>{};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('إضافة متجر جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المتجر (مثال: متجر الأدوات الإلكترونية)')),
                    if (_allCategories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('اختر الأصناف التابعة للمتجر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ..._allCategories.map((cat) {
                        final catId = cat['id'] as String;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(cat['name'] as String),
                          value: selectedCategoryIds.contains(catId),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedCategoryIds.add(catId);
                              } else {
                                selectedCategoryIds.remove(catId);
                              }
                            });
                          },
                          activeColor: AppColors.primary,
                        );
                      }),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      _addStore(nameCtrl.text.trim(), selectedCategoryIds.toList());
                      Navigator.pop(ctx);
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

  void _showEditWarehouseDialog(Map<String, dynamic> warehouse) {
    final nameCtrl = TextEditingController(text: warehouse['name'] as String? ?? '');
    final addressCtrl = TextEditingController(text: warehouse['address'] as String? ?? '');
    final maxStoresCtrl = TextEditingController(text: warehouse['max_stores']?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: AnimatedGlassCard(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                const Icon(Icons.edit_note_rounded, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text('تعديل تفاصيل المخزن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المخزن', prefixIcon: const Icon(Icons.warehouse_rounded),
                    filled: true, fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(
                    labelText: 'العنوان', prefixIcon: const Icon(Icons.location_on_rounded),
                    filled: true, fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: maxStoresCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الحد الأقصى للمتاجر (اختياري)',
                    hintText: 'لعدد غير محدود اتركه فارغاً',
                    prefixIcon: const Icon(Icons.numbers_rounded),
                    filled: true, fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
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
                            content: const Text('هل أنت متأكد من حذف المخزن؟ جميع المتاجر والمنتجات المرتبطة به قد تتأثر.'),
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
                          _deleteWarehouse(warehouse['id'] as String);
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
                            if (nameCtrl.text.trim().isNotEmpty) {
                              final maxStores = int.tryParse(maxStoresCtrl.text.trim());
                              _updateWarehouse(warehouse['id'] as String, nameCtrl.text.trim(), addressCtrl.text.trim(), maxStores);
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('حفظ التعديلات'),
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
      ),
    );
  }

  Future<void> _updateWarehouse(String id, String name, String address, int? maxStores) async {
    try {
      final updateData = {'name': name, 'address': address};
      if (maxStores != null) updateData['max_stores'] = maxStores.toString();
      else updateData['max_stores'] = null.toString();

      await _supabase.from('locations').update({
        'name': name,
        'address': address,
        'max_stores': maxStores,
      }).eq('id', id);
      
      _fetchWarehouseDetails();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _deleteWarehouse(String id) async {
    try {
      await _supabase.from('locations').delete().eq('id', id);
      if (mounted) {
        context.pop(); // Go back from warehouse details
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final isSupplier = userState.user?.role == 'supplier';
    
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
                title: Text('مخزن: ${_warehouseDetails?['name'] ?? widget.warehouseName}', style: theme.textTheme.titleMedium),
                floating: true,
                actions: [
                  if (!isSupplier) ...[
                    IconButton(
                      tooltip: 'تعديل المخزن',
                      icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                      onPressed: () {
                        if (_warehouseDetails != null) {
                          _showEditWarehouseDialog(_warehouseDetails!);
                        }
                      },
                    ),
                    IconButton(tooltip: 'إضافة متجر', icon: const Icon(Icons.add_circle_outline), onPressed: _showAddDialog),
                  ],
                ],
              ),
              if (_isLoading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_stores.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('لا يوجد متاجر في هذا المخزن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (!isSupplier)
                          ElevatedButton.icon(
                            onPressed: _showAddDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة متجر'),
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
                        final store = _stores[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AnimatedGlassCard(
                            padding: const EdgeInsets.all(16),
                            onTap: () => context.push('/inventory/store/${store['id']}', extra: store['name']),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.store_rounded, color: Colors.orange, size: 26),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(store['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                                      Text('متجر نشط', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _stores.length,
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
