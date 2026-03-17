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

  void _refresh() {
    setState(() => _future = _fetchSuppliers());
  }

  Future<List<_SupplierRow>> _fetchSuppliers() async {
    try {
      final companyId = await _repo.getCurrentCompanyIdOrThrow();
      final profiles = await _supabase
          .from('profiles')
          .select('id, full_name, phone_number, role, created_at')
          .eq('company_id', companyId)
          .eq('role', 'supplier')
          .order('created_at', ascending: false);

      final profileList = List<Map<String, dynamic>>.from(profiles as List);
      if (profileList.isEmpty) return [];

      final ids = profileList.map((e) => e['id']).toList();
      final locationsRows = await _supabase
          .from('profile_locations')
          .select('profile_id, locations(id, name, type)')
          .inFilter('profile_id', ids);

      final locList = List<Map<String, dynamic>>.from(locationsRows as List);
      final locByProfile = <String, Map<String, dynamic>>{};
      for (final r in locList) {
        final pid = r['profile_id'] as String?;
        final loc = r['locations'] as Map<String, dynamic>?;
        if (pid != null && loc != null) locByProfile[pid] = loc;
      }

      return profileList.map((p) {
        final id = p['id'] as String;
        return _SupplierRow(
          id: id,
          fullName: p['full_name'] as String? ?? '',
          phone: p['phone_number'] as String?,
          locationName: (locByProfile[id]?['name'] as String?) ?? 'غير محدد',
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
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
                  padding: const EdgeInsets.all(20),
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
                                final res = await context.push<bool>('/operations/suppliers/create');
                                if (res == true) _refresh();
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
                          final res = await context.push<bool>('/operations/suppliers/${s.id}/edit');
                          if (res == true) _refresh();
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_supplier_fab',
        onPressed: () async {
          final res = await context.push<bool>('/operations/suppliers/create');
          if (res == true) _refresh();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('مورد جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

