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

      final data = await _supabase.from('profile_locations').select('location_id').eq('profile_id', user.id);
      if (mounted) {
        setState(() {
          _assignedWarehouseIds = Set<String>.from(data.map((e) => e['location_id'] as String));
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
        setState(() {
          _warehouses = List<Map<String, dynamic>>.from(data);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final isSupplier = userState.user?.role == 'supplier';

    return Scaffold(
      floatingActionButton: isSupplier ? null : FloatingActionButton.extended(
        heroTag: 'add_warehouse_fab',
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('مخزن جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
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
