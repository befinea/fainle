import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

/// Allows the admin to manage per-employee page access.
/// Mobile-first design: list view → tap employee → slide to permissions.
class EmployeePermissionsScreen extends StatefulWidget {
  const EmployeePermissionsScreen({super.key});

  @override
  State<EmployeePermissionsScreen> createState() => _EmployeePermissionsScreenState();
}

class _EmployeePermissionsScreenState extends State<EmployeePermissionsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _errorMsg;
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selectedEmployee;
  Map<String, bool> _permissions = {};

  // Available permissions with their labels
  static const List<Map<String, String>> _allPermissions = [
    {'key': 'dashboard', 'label': 'لوحة التحكم', 'icon': 'dashboard'},
    {'key': 'pos', 'label': 'نقطة البيع (الكاشير)', 'icon': 'point_of_sale'},
    {'key': 'inventory', 'label': 'المخازن والمخزون', 'icon': 'inventory_2'},
    {'key': 'stores', 'label': 'المتاجر', 'icon': 'store'},
    {'key': 'operations', 'label': 'العمليات (وارد/صادر)', 'icon': 'swap_horiz'},
    {'key': 'reports', 'label': 'التقارير', 'icon': 'analytics'},
    {'key': 'settings', 'label': 'الإعدادات', 'icon': 'settings'},
    {'key': 'categories', 'label': 'إدارة الأصناف', 'icon': 'category'},
    {'key': 'barcode', 'label': 'ماسح الباركود', 'icon': 'qr_code_scanner'},
    {'key': 'ai_assistant', 'label': 'المساعد الذكي', 'icon': 'auto_awesome'},
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final companyId = profile['company_id'];

      debugPrint('RBAC: Loading employees for company $companyId, excluding user ${user.id}');

      // Select only columns that definitely exist
      final data = await _supabase
          .from('profiles')
          .select('id, full_name, role, custom_permissions')
          .eq('company_id', companyId)
          .neq('id', user.id);

      debugPrint('RBAC: Found ${(data as List).length} employees');

      if (mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(data);
          _loading = false;
          if (_employees.isEmpty) {
            _errorMsg = 'لا يوجد موظفين آخرين في شركتك حالياً';
          }
        });
      }
    } catch (e) {
      debugPrint('Load employees error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'خطأ في تحميل الموظفين: $e';
        });
      }
    }
  }

  void _selectEmployee(Map<String, dynamic> emp) {
    final saved = emp['custom_permissions'] as Map<String, dynamic>?;
    final perms = <String, bool>{};
    for (final p in _allPermissions) {
      final key = p['key']!;
      if (saved != null && saved.containsKey(key)) {
        perms[key] = saved[key] == true;
      } else {
        perms[key] = _defaultPermForRole(emp['role'] as String? ?? 'cashier', key);
      }
    }
    setState(() {
      _selectedEmployee = emp;
      _permissions = perms;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedEmployee = null;
      _permissions = {};
    });
  }

  bool _defaultPermForRole(String role, String key) {
    switch (role) {
      case 'admin':
        return true;
      case 'cashier':
        return ['dashboard', 'pos', 'barcode'].contains(key);
      case 'warehouse_worker':
        return ['dashboard', 'inventory', 'barcode'].contains(key);
      case 'supplier':
        return ['dashboard', 'pos', 'inventory', 'operations'].contains(key);
      default:
        return ['dashboard'].contains(key);
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedEmployee == null) return;

    try {
      final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';

      if (serviceRoleKey.isEmpty || supabaseUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطأ: تأكد من ضبط مفتاح الخدمة ورابط Supabase في ملف .env'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final adminClient = SupabaseClient(supabaseUrl, serviceRoleKey);
      try {
        await adminClient
            .from('profiles')
            .update({'custom_permissions': _permissions})
            .eq('id', _selectedEmployee!['id']);
      } finally {
        adminClient.dispose();
      }

      final index = _employees.indexWhere((e) => e['id'] == _selectedEmployee!['id']);
      if (index != -1) {
        _employees[index]['custom_permissions'] = Map<String, dynamic>.from(_permissions);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الصلاحيات بنجاح'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      debugPrint('Save permissions error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الصلاحيات: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'dashboard': return Icons.dashboard_rounded;
      case 'point_of_sale': return Icons.point_of_sale_rounded;
      case 'inventory_2': return Icons.inventory_2_rounded;
      case 'store': return Icons.store_rounded;
      case 'swap_horiz': return Icons.swap_horiz_rounded;
      case 'analytics': return Icons.analytics_rounded;
      case 'settings': return Icons.settings_rounded;
      case 'category': return Icons.category_rounded;
      case 'qr_code_scanner': return Icons.qr_code_scanner_rounded;
      case 'auto_awesome': return Icons.auto_awesome_rounded;
      default: return Icons.check_circle;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'cashier': return 'كاشير';
      case 'warehouse_worker': return 'عامل مخزن';
      case 'supplier': return 'مورد';
      default: return role ?? 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedEmployee != null
              ? 'صلاحيات: ${_selectedEmployee!['full_name']}'
              : 'إدارة الصلاحيات',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          onPressed: () {
            if (_selectedEmployee != null) {
              _clearSelection();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (_selectedEmployee != null)
            TextButton.icon(
              onPressed: _savePermissions,
              icon: const Icon(Icons.save_rounded, size: 20),
              label: const Text('حفظ'),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.95),
              Colors.purple.withOpacity(0.05),
            ],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _selectedEmployee != null
                ? _buildPermissionsView(theme)
                : _buildEmployeeList(theme),
      ),
    );
  }

  Widget _buildEmployeeList(ThemeData theme) {
    if (_errorMsg != null && _employees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline_rounded, size: 72, color: Colors.grey.withOpacity(0.3)),
              const SizedBox(height: 20),
              Text(_errorMsg!, style: const TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      itemCount: _employees.length,
      itemBuilder: (ctx, i) {
        final emp = _employees[i];
        final name = emp['full_name'] as String? ?? 'بدون اسم';
        final role = _roleLabel(emp['role'] as String?);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedGlassCard(
            onTap: () => _selectEmployee(emp),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1) : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(role, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionsView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      children: [
        // Info card
        AnimatedGlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'فعّل أو عطّل الصفحات المتاحة لهذا الموظف',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Permissions toggles
        ..._allPermissions.map((p) {
          final key = p['key']!;
          final enabled = _permissions[key] ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnimatedGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (enabled ? AppColors.primary : Colors.grey).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getIcon(p['icon']!), color: enabled ? AppColors.primary : Colors.grey, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(p['label']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Switch(
                    value: enabled,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _permissions[key] = val),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
