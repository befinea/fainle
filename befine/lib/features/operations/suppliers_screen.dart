import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/error/exceptions.dart';
import 'data/operations_repository.dart';
import '../../ui/widgets/animated_glass_card.dart'; // IMPORT NEW WIDGET

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _supabase = Supabase.instance.client;
  late final OperationsRepository _repo;
  late Future<List<_SupplierRow>> _future;

  @override
  void initState() {
    super.initState();
    _repo = OperationsRepository(_supabase);
    _future = _fetchSuppliers();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchSuppliers());
    await _future;
  }

  Future<List<_SupplierRow>> _fetchSuppliers() async {
    try {
      final companyId = await _repo.getCurrentCompanyIdOrThrow();
      final profiles = await _supabase
          .from('profiles')
          .select('id, full_name, phone_number, role, created_at, store_id')
          .eq('company_id', companyId)
          .eq('role', 'supplier')
          .order('created_at', ascending: false);

      final profileList = List<Map<String, dynamic>>.from(profiles as List);
      if (profileList.isEmpty) return [];

      final storeIds = profileList.map((e) => e['store_id'] as String?).where((id) => id != null).toSet().toList();
      Map<String, String> locationNameMap = {};
      
      if (storeIds.isNotEmpty) {
        final locs = await _supabase.from('locations').select('id, name').inFilter('id', storeIds);
        for (final loc in locs) {
          locationNameMap[loc['id'] as String] = loc['name'] as String;
        }
      }

      return profileList.map((p) {
        final storeId = p['store_id'] as String?;
        return _SupplierRow(
          id: p['id'] as String,
          fullName: p['full_name'] as String? ?? '',
          phone: p['phone_number'] as String?,
          locationName: storeId != null ? (locationNameMap[storeId] ?? 'غير محدد') : 'غير محدد',
        );
      }).toList();
    } catch (e) {
      throw ServerException('Failed to fetch suppliers: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.background.withOpacity(0.95),
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<_SupplierRow>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('حدث خطأ: ${snapshot.error}'));
              }

              final items = snapshot.data ?? const [];
              
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                  itemCount: items.length + 1,
                  itemBuilder: (ctx, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الموردون', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.person_add_rounded),
                              onPressed: () async {
                                await context.push<bool>('/operations/suppliers/create');
                                _refresh();
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.surface,
                                foregroundColor: theme.colorScheme.onSurface,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    final s = items[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnimatedGlassCard(
                        onTap: () async {
                          await context.push<bool>('/operations/suppliers/${s.id}/edit');
                          _refresh();
                        },
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14)
                              ),
                              child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                  Text(
                                    'المخزن: ${s.locationName}${s.phone == null ? '' : ' • ${s.phone}'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          heroTag: 'add_supplier_fab',
          onPressed: () async {
            await context.push<bool>('/operations/suppliers/create');
            _refresh();
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('مورد جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _SupplierRow {
  final String id;
  final String fullName;
  final String? phone;
  final String locationName;

  _SupplierRow({required this.id, required this.fullName, required this.phone, required this.locationName});
}

