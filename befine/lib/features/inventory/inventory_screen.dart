import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final userState = ref.watch(authProvider);
    final isSupplier = userState.user?.role == 'supplier';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : null,
          floatingActionButtonLocation: isDesktop ? null : FloatingActionButtonLocation.centerFloat,
          floatingActionButton: (isSupplier || isDesktop) ? null : _buildMobileFab(),
          body: isDesktop ? _buildDesktop(context, isDark, isSupplier) : _buildMobile(context, isDark, isSupplier),
        );
      },
    );
  }

  Widget _buildMobileFab() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.primary, // bg-primary
        borderRadius: BorderRadius.circular(999), // rounded-full
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)), // shadow-lg shadow-primary/40
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAddDialog,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // px-6 py-4
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 8), // gap-2
                Text('مخزن جديد', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context, bool isDark, bool isSupplier) {
    return Column(
      children: [
        // TopAppBar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff0f172a).withOpacity(0.4) : Colors.white.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.05), blurRadius: 40, offset: const Offset(0, 20)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20)],
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('المخازن', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  ],
                ),
                if (!isSupplier)
                   InkWell(
                     onTap: _showSelectWarehouseForEdit,
                     borderRadius: BorderRadius.circular(12),
                     child: Container(
                       width: 40, height: 40,
                       decoration: BoxDecoration(
                         color: Colors.grey.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: const Icon(Icons.edit_rounded, color: AppColors.primary),
                     ),
                   ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchWarehouses,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                children: [
                  // Search Bar
                  AnimatedGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    borderRadius: 16,
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.inter(),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن مخزن...',
                        hintStyle: GoogleFonts.inter(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearch();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (_filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.warehouse_outlined, size: 64, color: AppColors.primary.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('لا توجد مخازن', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._filtered.map((wh) => _buildMobileWarehouseCard(wh, isDark, isSupplier)).toList(),
                ],
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildMobileWarehouseCard(Map<String, dynamic> wh, bool isDark, bool isSupplier) {
    final isAssigned = !isSupplier || _assignedWarehouseIds.contains(wh['id']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedGlassCard(
        onTap: isAssigned ? () => context.push('/inventory/warehouse/${wh['id']}', extra: wh['name']) : null,
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Opacity(
          opacity: isAssigned ? 1.0 : 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: (isAssigned ? AppColors.primary : Colors.grey).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: Icon(Icons.warehouse_rounded, color: isAssigned ? AppColors.primary : Colors.grey, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wh['name'] ?? '', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          isAssigned ? (wh['address'] as String? ?? 'بدون عنوان') : 'مخزن مقفل',
                          style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                  Icon(isAssigned ? Icons.chevron_left_rounded : Icons.lock_outline_rounded, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ],
              ),
              if (isAssigned) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('عرض المخزون', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, bool isDark, bool isSupplier) {
    return Padding(
      padding: const EdgeInsets.all(32).copyWith(top: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('إدارة المخازن', style: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
              Row(
                children: [
                  if (!isSupplier)
                    InkWell(
                      onTap: _showSelectWarehouseForEdit,
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedGlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        borderRadius: 999,
                        child: Row(
                          children: [
                            const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('تعديل مخزن', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  if (!isSupplier) const SizedBox(width: 16),
                  if (!isSupplier)
                    InkWell(
                      onTap: _showAddDialog,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('مخزن جديد', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Search Section
          SizedBox(
            width: 800,
            child: AnimatedGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              borderRadius: 16,
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.inter(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'ابحث عن مخزن...',
                  hintStyle: GoogleFonts.inter(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchCtrl.text.isEmpty ? 'ليس لديك مخازن بعد' : 'لا يوجد نتائج تطابق بحثك',
                          style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final wh = _filtered[i];
                          final isAssigned = !isSupplier || _assignedWarehouseIds.contains(wh['id']);
                          
                          return AnimatedGlassCard(
                            onTap: isAssigned ? () => context.push('/inventory/warehouse/${wh['id']}', extra: wh['name']) : null,
                            padding: const EdgeInsets.all(24),
                            borderRadius: 24,
                            child: Opacity(
                              opacity: isAssigned ? 1.0 : 0.5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (isAssigned ? AppColors.primary : Colors.grey).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                                        ),
                                        child: Icon(Icons.warehouse_rounded, color: isAssigned ? AppColors.primary : Colors.grey, size: 32),
                                      ),
                                      const Spacer(),
                                      Icon(isAssigned ? Icons.arrow_outward_rounded : Icons.lock_outline_rounded, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(wh['name'] ?? '', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 24)),
                                  const SizedBox(height: 8),
                                  Text(
                                    isAssigned ? (wh['address'] as String? ?? 'بدون عنوان') : 'مخزن مقفل',
                                    style: GoogleFonts.inter(fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
