import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../ui/widgets/animated_glass_card.dart';

class StoresListScreen extends StatefulWidget {
  const StoresListScreen({super.key});

  @override
  State<StoresListScreen> createState() => _StoresListScreenState();
}

class _StoresListScreenState extends State<StoresListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  String? _companyId;
  int _maxStores = 1;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      final user = _supabase.auth.currentUser!;
      final profile = await _supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'] as String;

      final companyResponse = await _supabase
          .from('companies')
          .select('max_stores')
          .eq('id', _companyId!)
          .single();
      _maxStores = companyResponse['max_stores'] as int? ?? 1;

      final data = await _supabase
          .from('locations')
          .select('id, name, parent_id, created_at, address')
          .eq('company_id', _companyId!)
          .eq('type', 'store')
          .order('created_at', ascending: false);

      // Load warehouse names for each store
      final stores = List<Map<String, dynamic>>.from(data);
      for (var store in stores) {
        if (store['parent_id'] != null) {
          try {
            final wh = await _supabase
                .from('locations')
                .select('name')
                .eq('id', store['parent_id'])
                .single();
            store['warehouse_name'] = wh['name'];
          } catch (_) {
            store['warehouse_name'] = 'غير محدد';
          }
        } else {
          store['warehouse_name'] = 'غير مرتبط';
        }
      }

      if (mounted) {
        setState(() {
          _stores = stores;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stores: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
            const SizedBox(width: 10),
            const Text('تجاوز الحد المسموح', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'لقد وصلت إلى الحد الأقصى للمتاجر المسموح بها في خطتك الحالية ($_maxStores متجر).\n\nيرجى ترقية خطتك لإضافة المزيد من المتاجر.',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/settings/plans');
            },
            child: const Text('ترقية الخطة'),
          ),
        ],
      ),
    );
  }

  void _showAddStoreDialog() {
    if (_stores.length >= _maxStores) {
      _showUpgradePrompt();
      return;
    }

    final nameCtrl = TextEditingController();
    String? selectedWarehouseId;
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
              if (mounted) {
                setDialogState(() => isLoading = false);
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('إضافة متجر جديد', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم المتجر',
                      prefixIcon: const Icon(Icons.store_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
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
                        labelText: 'تنسيب إلى مخزن (مطلوب)',
                        prefixIcon: const Icon(Icons.warehouse_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      items: warehousesInfo.map((wh) {
                        final whCompanyId = wh['company_id'] as String?;
                        final isGlobal = whCompanyId != _companyId;
                        final name = (wh['name'] as String) + (isGlobal ? ' (مخزن رئيسي)' : '');
                        final address = wh['address'] as String? ?? 'بدون عنوان';
                        final max = wh['max_stores'] as int? ?? 5;
                        final reserved = wh['reserved'] as int? ?? 0;
                        final available = wh['available'] as int? ?? 0;
                        final isFull = available <= 0;

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
                                '$address | الإجمالي: $max | محجوز: $reserved | متاح: $available',
                                style: TextStyle(fontSize: 11, color: isFull ? Colors.red.shade400 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedWarehouseId = v),
                      hint: warehousesInfo.isEmpty
                          ? const Text('لا توجد مخازن! راجع المدير')
                          : const Text('اختر المخزن المرجعي للمتجر'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || selectedWarehouseId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text('الرجاء إدخال اسم المتجر واختيار المخزن'), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  try {
                    await _supabase.from('locations').insert({
                      'company_id': _companyId,
                      'parent_id': selectedWarehouseId,
                      'name': nameCtrl.text.trim(),
                      'type': 'store',
                    });

                    // Audit Log
                    await _supabase.from('audit_logs').insert({
                      'company_id': _companyId,
                      'user_id': _supabase.auth.currentUser!.id,
                      'action': 'store_created',
                      'entity_type': 'location',
                      'details': {
                        'name': nameCtrl.text.trim(),
                        'warehouse_id': selectedWarehouseId,
                      },
                    });

                    Navigator.pop(ctx);
                    _loadStores();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('متاجري', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadStores,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStoreDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('متجر جديد'),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _stores.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_mall_directory_outlined, size: 72, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('لا توجد متاجر بعد', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                        const SizedBox(height: 8),
                        Text('اضغط + لإضافة متجر جديد', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadStores,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: _stores.length,
                      itemBuilder: (context, index) {
                        final store = _stores[index];
                        return _StoreCard(
                          name: store['name'] as String? ?? 'متجر',
                          warehouseName: store['warehouse_name'] as String? ?? '',
                          onTap: () {
                            context.push(
                              '/inventory/store/${store['id']}',
                              extra: store['name'] as String? ?? 'متجر',
                            );
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String name;
  final String warehouseName;
  final VoidCallback onTap;

  const _StoreCard({
    required this.name,
    required this.warehouseName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryVariant],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.store_rounded, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warehouse_outlined, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    warehouseName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
