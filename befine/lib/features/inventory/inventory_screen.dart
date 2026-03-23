import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/application/auth_service.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _filtered = [];
  final _searchCtrl = TextEditingController();
  Set<String> _assignedWarehouseIds = {};

  @override
  void initState() {
    super.initState();
    _fetchAssignedWarehouses().then((_) => _fetchWarehouses());
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _fetchAssignedWarehouses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profileState = ref.read(authProvider);
      if (profileState.user?.role != 'supplier') return; // Only relevant for suppliers

      final data = await _supabase.from('profiles').select('store_id').eq('id', user.id).single();
      final storeId = data['store_id'] as String?;
      if (storeId == null) return;

      final locData = await _supabase.from('locations').select('id, type, parent_id').eq('id', storeId).single();
      final type = locData['type'];
      final assignedWh = type == 'warehouse' ? locData['id'] : locData['parent_id'];

      if (assignedWh != null && mounted) {
        setState(() {
          _assignedWarehouseIds = {assignedWh as String};
        });
      }
    } catch (e) {
      debugPrint('Error fetching assigned warehouses: $e');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _warehouses
          : _warehouses.where((w) => (w['name'] as String).toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _fetchWarehouses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final data = await _supabase
          .from('locations')
          .select()
          .eq('company_id', profile['company_id'])
          .eq('type', 'warehouse')
          .order('created_at');
      if (mounted) {
        var allWarehouses = List<Map<String, dynamic>>.from(data);
        // Filter for suppliers: only show assigned warehouses
        final profileState = ref.read(authProvider);
        if (profileState.user?.role == 'supplier' && _assignedWarehouseIds.isNotEmpty) {
          allWarehouses = allWarehouses.where((w) => _assignedWarehouseIds.contains(w['id'])).toList();
        }
        setState(() {
          _warehouses = allWarehouses;
          _filtered = _warehouses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching warehouses: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWarehouse(String name, String address, int? maxStores) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final insertData = <String, dynamic>{
        'company_id': profile['company_id'],
        'name': name,
        'type': 'warehouse',
        'address': address,
      };
      if (maxStores != null) insertData['max_stores'] = maxStores;
      await _supabase.from('locations').insert(insertData);
      _fetchWarehouses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في الإضافة: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final maxStoresCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة مخزن جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المخزن')),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 12),
              TextField(
                controller: maxStoresCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الأقصى للمتاجر (اختياري)',
                  hintText: 'اتركه فارغاً لعدد غير محدود',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                final maxStores = int.tryParse(maxStoresCtrl.text.trim());
                _addWarehouse(nameCtrl.text.trim(), addressCtrl.text.trim(), maxStores);
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showSelectWarehouseForEdit() {
    if (_warehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد مخازن للتعديل')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(4))),
            const Padding(padding: EdgeInsets.all(16), child: Text('اختر المخزن للتعديل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _warehouses.length,
                itemBuilder: (context, index) {
                  final wh = _warehouses[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AnimatedGlassCard(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showEditWarehouseDialog(wh);
                      },
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.warehouse_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(wh['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(wh['address'] as String? ?? 'بدون عنوان', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_rounded, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
    );
  }

  Future<void> _updateWarehouse(String id, String name, String address, int? maxStores) async {
    try {
      final updateData = {'name': name, 'address': address};
      if (maxStores != null) updateData['max_stores'] = maxStores.toString();
      else updateData['max_stores'] = null.toString(); // Supabase expects null if actually null

      await _supabase.from('locations').update({
        'name': name,
        'address': address,
        'max_stores': maxStores,
      }).eq('id', id);
      
      _fetchWarehouses();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _deleteWarehouse(String id) async {
    try {
      await _supabase.from('locations').delete().eq('id', id);
      _fetchWarehouses();
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isSupplier ? null : FloatingActionButton.extended(
        heroTag: 'add_warehouse_fab',
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('مخزن جديد', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
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
          child: RefreshIndicator(
            onRefresh: _fetchWarehouses,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  title: Text('المخازن', style: theme.textTheme.titleLarge),
                  floating: true,
                  actions: [
                    if (!isSupplier)
                      IconButton(
                        tooltip: 'تعديل مخزن',
                        icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                        onPressed: _showSelectWarehouseForEdit,
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: AnimatedGlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن مخزن...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _onSearch();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (_isLoading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (_filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text('لا توجد مخازن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (!isSupplier)
                            TextButton.icon(
                              onPressed: _showAddDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة مخزن'),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final wh = _filtered[i];
                          final isAssigned = !isSupplier || _assignedWarehouseIds.contains(wh['id']);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnimatedGlassCard(
                              padding: const EdgeInsets.all(16),
                              onTap: isAssigned ? () => context.push('/inventory/warehouse/${wh['id']}', extra: wh['name']) : null,
                              child: Opacity(
                                opacity: isAssigned ? 1.0 : 0.5,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isAssigned ? AppColors.primary.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(Icons.warehouse_rounded, color: isAssigned ? AppColors.primary : Colors.grey, size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(wh['name'], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: isAssigned ? null : Colors.grey)),
                                          const SizedBox(height: 4),
                                          Text(
                                            isAssigned ? (wh['address'] as String? ?? 'لا يوجد عنوان محدد') : 'مخزن مقفل',
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(isAssigned ? Icons.arrow_forward_ios : Icons.lock_outline, size: 14, color: Colors.grey.shade400),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
