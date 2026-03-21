import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

class CompanyDetailScreen extends StatefulWidget {
  final String companyId;
  final String companyName;

  const CompanyDetailScreen({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  Map<String, dynamic>? _company;
  Map<String, dynamic>? _owner;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadCompanyInfo(),
      _loadEmployees(),
      _loadStores(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCompanyInfo() async {
    try {
      final data = await _supabase
          .from('companies')
          .select()
          .eq('id', widget.companyId)
          .single();
      if (mounted) setState(() => _company = data);
    } catch (e) {
      debugPrint('Error loading company: $e');
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('id, full_name, email, role, phone_number, created_at')
          .eq('company_id', widget.companyId)
          .order('created_at', ascending: true);

      final list = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          // The first admin is typically the owner
          _owner = list.firstWhere(
            (p) => p['role'] == 'admin',
            orElse: () => list.isNotEmpty ? list.first : {},
          );
          _employees = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  Future<void> _loadStores() async {
    try {
      final data = await _supabase
          .from('locations')
          .select('id, name, type, address, created_at, parent_id')
          .eq('company_id', widget.companyId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _stores = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading stores: $e');
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'store_manager':
        return 'مدير متجر';
      case 'cashier':
        return 'كاشير';
      case 'warehouse_worker':
        return 'عامل مخزن';
      case 'supplier':
        return 'مورد';
      default:
        return role ?? 'غير محدد';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.deepPurple;
      case 'store_manager':
        return Colors.blue;
      case 'cashier':
        return Colors.teal;
      case 'warehouse_worker':
        return Colors.orange;
      case 'supplier':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'store_manager':
        return Icons.store_rounded;
      case 'cashier':
        return Icons.point_of_sale_rounded;
      case 'warehouse_worker':
        return Icons.warehouse_rounded;
      case 'supplier':
        return Icons.local_shipping_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _locationTypeLabel(String? type) {
    switch (type) {
      case 'warehouse':
        return 'مستودع';
      case 'store':
        return 'متجر';
      default:
        return type ?? 'غير محدد';
    }
  }

  IconData _locationTypeIcon(String? type) {
    switch (type) {
      case 'warehouse':
        return Icons.warehouse_rounded;
      case 'store':
        return Icons.storefront_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.companyName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.person_rounded), text: 'صاحب الشركة'),
            Tab(icon: Icon(Icons.people_rounded), text: 'الموظفين'),
            Tab(icon: Icon(Icons.store_rounded), text: 'المتاجر'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.9),
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOwnerTab(theme, isDark),
                  _buildEmployeesTab(theme, isDark),
                  _buildStoresTab(theme, isDark),
                ],
              ),
      ),
    );
  }

  // ─────────────── TAB 1: Owner ───────────────
  Widget _buildOwnerTab(ThemeData theme, bool isDark) {
    if (_owner == null || _owner!.isEmpty) {
      return _buildEmptyState(Icons.person_off_rounded, 'لم يتم العثور على صاحب الشركة');
    }

    final plan = _company?['subscription_plan'] as String? ?? 'free';
    final isActive = _company?['is_active'] as bool? ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Owner Card
          AnimatedGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryVariant],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      (_owner!['full_name'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _owner!['full_name'] as String? ?? 'غير معروف',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '👑 مالك الشركة',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_owner!['email'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        _owner!['email'] as String,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
                if (_owner!['phone_number'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_rounded, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        _owner!['phone_number'] as String,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'تاريخ الانضمام: ${_formatDate(_owner!['created_at'] as String?)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Company Info Card
          AnimatedGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.business_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'معلومات الشركة',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'اسم الشركة', value: _company?['name'] ?? '-'),
                _InfoRow(
                  label: 'الباقة',
                  value: plan == 'premium' ? '⭐ مميزة' : plan == 'basic' ? '💼 أساسية' : '🆓 مجانية',
                ),
                _InfoRow(
                  label: 'الحالة',
                  value: isActive ? '✅ نشطة' : '⛔ متوقفة',
                ),
                _InfoRow(
                  label: 'الحد الأقصى للمخازن',
                  value: '${_company?['max_warehouses'] ?? 1}',
                ),
                _InfoRow(
                  label: 'الحد الأقصى للمتاجر',
                  value: '${_company?['max_stores'] ?? 1}',
                ),
                if (_company?['email_domain'] != null)
                  _InfoRow(label: 'نطاق البريد', value: _company!['email_domain']),
                _InfoRow(
                  label: 'إعداد الشركة',
                  value: _company?['onboarding_completed'] == true ? 'مكتمل ✅' : 'غير مكتمل ⏳',
                ),
                _InfoRow(
                  label: 'تاريخ الإنشاء',
                  value: _formatDate(_company?['created_at'] as String?),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people_rounded,
                  label: 'إجمالي الموظفين',
                  value: '${_employees.length}',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.store_rounded,
                  label: 'إجمالي الفروع',
                  value: '${_stores.length}',
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────── TAB 2: Employees ───────────────
  Widget _buildEmployeesTab(ThemeData theme, bool isDark) {
    if (_employees.isEmpty) {
      return _buildEmptyState(Icons.people_outline_rounded, 'لا يوجد موظفين مسجلين');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        final emp = _employees[index];
        final role = emp['role'] as String? ?? '';
        final name = emp['full_name'] as String? ?? 'بدون اسم';
        final phone = emp['phone_number'] as String?;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedGlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _roleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_roleIcon(role), color: _roleColor(role), size: 24),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _roleColor(role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _roleLabel(role),
                              style: TextStyle(
                                fontSize: 11,
                                color: _roleColor(role),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (phone != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Date
                Text(
                  _formatDate(emp['created_at'] as String?),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────── TAB 3: Stores ───────────────
  Widget _buildStoresTab(ThemeData theme, bool isDark) {
    if (_stores.isEmpty) {
      return _buildEmptyState(Icons.store_outlined, 'لا توجد متاجر أو مستودعات');
    }

    // Separate warehouses and stores
    final warehouses = _stores.where((s) => s['type'] == 'warehouse').toList();
    final stores = _stores.where((s) => s['type'] == 'store').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warehouses Section
          if (warehouses.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warehouse_rounded, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'المستودعات (${warehouses.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...warehouses.map((w) => _buildLocationCard(w, theme)),
            const SizedBox(height: 24),
          ],

          // Stores Section
          if (stores.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.teal, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'المتاجر (${stores.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...stores.map((s) => _buildLocationCard(s, theme)),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location, ThemeData theme) {
    final type = location['type'] as String?;
    final name = location['name'] as String? ?? 'فرع';
    final address = location['address'] as String?;
    final parentId = location['parent_id'] as String?;

    // Find parent warehouse name if this is a store
    String? parentName;
    if (parentId != null) {
      final parent = _stores.firstWhere(
        (s) => s['id'] == parentId,
        orElse: () => <String, dynamic>{},
      );
      parentName = parent['name'] as String?;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (type == 'warehouse' ? Colors.orange : Colors.teal).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _locationTypeIcon(type),
                color: type == 'warehouse' ? Colors.orange : Colors.teal,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (type == 'warehouse' ? Colors.orange : Colors.teal).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _locationTypeLabel(type),
                          style: TextStyle(
                            fontSize: 11,
                            color: type == 'warehouse' ? Colors.orange : Colors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (parentName != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.link_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'تابع لـ: $parentName',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (address != null && address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            address,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Text(
              _formatDate(location['created_at'] as String?),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ─────────────── Helper Widgets ───────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
