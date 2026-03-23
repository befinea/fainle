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

  void _showSelectStoreForEdit() {
    if (_stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد متاجر للتعديل')));
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
            const Padding(padding: EdgeInsets.all(16), child: Text('اختر المتجر للتعديل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _stores.length,
                itemBuilder: (context, index) {
                  final store = _stores[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AnimatedGlassCard(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showEditStoreDialog(store);
                      },
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.store_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(store['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(store['warehouse_name'] as String? ?? 'بدون مخزن', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
      _loadStores();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _deleteStore(String id) async {
    try {
      await _supabase.from('locations').delete().eq('id', id);
      _loadStores();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        title: const Text('متاجري', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'تعديل متجر',
            onPressed: _showSelectStoreForEdit,
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _loadStores,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_store_fab',
        onPressed: _showAddStoreDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded, size: 20),
        label: const Text('متجر جديد', style: TextStyle(fontWeight: FontWeight.bold)),
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
