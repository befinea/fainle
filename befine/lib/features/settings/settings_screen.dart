import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../ui/widgets/animated_glass_card.dart';
import '../auth/application/auth_service.dart';
import '../auth/application/permissions_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  String? _companyName;
  String? _subscriptionPlan;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select('full_name, phone_number, role, company_id')
          .eq('id', user.id)
          .single();

      // Load company name
      try {
        if (data['company_id'] != null) {
          final companyData = await _supabase
              .from('companies')
              .select('name, subscription_plan')
              .eq('id', data['company_id'])
              .single();
          _companyName = companyData['name'] as String?;
          _subscriptionPlan = companyData['subscription_plan'] as String?;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _profile = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _supabase.auth.signOut();
      if (mounted) context.go('/auth');
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'store_manager': return 'مدير متجر';
      case 'supplier': return 'مورد';
      case 'warehouse_worker': return 'عامل مخزن';
      case 'cashier': return 'كاشير';
      default: return role ?? 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : isDesktop
                  ? _buildDesktop(context, isDark)
                  : _buildMobile(context, isDark),
        );
      },
    );
  }

  Widget _buildAvatar(bool isSupplier) {
    final userState = ref.watch(authProvider);
    final user = userState.user;
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              (_profile?['full_name'] as String? ?? 'م').substring(0, 1),
              style: GoogleFonts.manrope(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.name ?? _profile?['full_name'] as String? ?? 'المستخدم',
          style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: (isSupplier ? Colors.orange : AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (isSupplier ? Colors.orange : AppColors.primary).withOpacity(0.2)),
          ),
          child: Text(
            _roleLabel(user?.role ?? _profile?['role'] as String?),
            style: TextStyle(
              color: isSupplier ? Colors.orange : AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(bool isDark) {
    final userState = ref.watch(authProvider);
    final user = userState.user;
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('معلومات الحساب', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.email_outlined, label: 'البريد الإلكتروني', value: user?.email ?? 'غير متوفر'),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.phone_outlined, label: 'رقم الهاتف', value: _profile?['phone_number'] as String? ?? 'غير محدد'),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.badge_outlined, label: 'الصلاحية', value: _roleLabel(user?.role ?? _profile?['role'] as String?)),
          if (_companyName != null) ...[
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.business_rounded, label: 'الشركة', value: _companyName!),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSettingsTiles(bool isDark, bool isSupplier, bool isAdmin) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    return [
      // Section Header
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('خيارات النظام', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
      ),

      // Theme Toggle
      AnimatedGlassCard(
        padding: const EdgeInsets.all(4),
        borderRadius: 20,
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDarkMode ? Colors.amber : Colors.indigo).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDarkMode ? Colors.amber : Colors.indigo,
            ),
          ),
          title: Text('الوضع الليلي', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          subtitle: Text(isDarkMode ? 'مفعّل' : 'معطّل', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
          value: isDarkMode,
          activeColor: AppColors.primary,
          onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
        ),
      ),
      const SizedBox(height: 12),

      // Categories - show for admins always, or for any user if categories permission is enabled
      if (isAdmin || (ref.watch(customPermissionsProvider).valueOrNull?['categories'] == true)) ...[
        _SettingsTile(icon: Icons.category_rounded, color: Colors.teal, title: 'إدارة الأصناف', subtitle: 'إضافة وتعديل أصناف المنتجات', onTap: () => context.push('/settings/categories')),
        const SizedBox(height: 12),
      ],

      // Admin sections
      if (isAdmin) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 12),
          child: Text('إدارة الشركة', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
        ),
        if (['premium', 'gold', 'enterprise'].contains(_subscriptionPlan)) ...[
          _SettingsTile(icon: Icons.warehouse_rounded, color: Colors.amber.shade700, title: 'إدارة المخازن', subtitle: 'إضافة مخازن خاصة بك وإدارتها', onTap: () => context.push('/inventory')),
          const SizedBox(height: 12),
        ],
        _SettingsTile(icon: Icons.people_rounded, color: Colors.blue, title: 'إدارة الموظفين', subtitle: 'دعوة موظفين جدد وإدارة الصلاحيات', onTap: () => context.push('/settings/employees')),
        const SizedBox(height: 12),
        _SettingsTile(icon: Icons.admin_panel_settings_rounded, color: Colors.purple, title: 'صلاحيات الموظفين', subtitle: 'تحكم بالصفحات المتاحة لكل موظف', onTap: () => context.push('/settings/permissions')),
        const SizedBox(height: 12),
        if (_profile?['company_id'] == '00000000-0000-0000-0000-000000000001') ...[
          _SettingsTile(icon: Icons.business_center_rounded, color: Colors.deepPurple, title: 'إدارة الشركات', subtitle: 'عرض وإدارة جميع الشركات المسجلة', onTap: () => context.push('/settings/companies')),
          const SizedBox(height: 12),
        ],
        _SettingsTile(icon: Icons.history_rounded, color: Colors.orange, title: 'سجل النشاطات', subtitle: 'متابعة كل الحركات والعمليات', onTap: () => context.push('/settings/audit-log')),
        const SizedBox(height: 12),
      ],

      // Supplier Portal
      if (isSupplier) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 12),
          child: Text('بوابة المورد', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
        ),
        _SettingsTile(icon: Icons.local_shipping_rounded, color: Colors.orange, title: 'بوابة المورد', subtitle: 'عرض الحركات والفواتير الخاصة بك', onTap: () => context.push('/supplier-portal')),
        const SizedBox(height: 12),
      ],

      // Logout
      _SettingsTile(icon: Icons.logout_rounded, color: AppColors.error, title: 'تسجيل الخروج', subtitle: 'الخروج من الحساب الحالي', onTap: () => _signOut(context), isDestructive: true),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildMobile(BuildContext context, bool isDark) {
    final userState = ref.watch(authProvider);
    final user = userState.user;
    final isSupplier = user?.role == 'supplier';
    final isAdmin = user?.role == 'admin' || _profile?['role'] == 'admin';

    return Column(
      children: [
        // Glass Top Bar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff0f172a).withOpacity(0.4) : Colors.white.withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.05), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20)],
                ),
                child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Text('الإعدادات', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: _buildAvatar(isSupplier)),
              const SizedBox(height: 32),
              _buildInfoCard(isDark),
              const SizedBox(height: 32),
              ..._buildSettingsTiles(isDark, isSupplier, isAdmin),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context, bool isDark) {
    final userState = ref.watch(authProvider);
    final user = userState.user;
    final isSupplier = user?.role == 'supplier';
    final isAdmin = user?.role == 'admin' || _profile?['role'] == 'admin';

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الإعدادات', style: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 48),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Avatar + Info
                Expanded(
                  flex: 3,
                  child: ListView(
                    children: [
                      _buildAvatar(isSupplier),
                      const SizedBox(height: 32),
                      _buildInfoCard(isDark),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                // Right: Settings tiles
                Expanded(
                  flex: 7,
                  child: ListView(
                    children: _buildSettingsTiles(isDark, isSupplier, isAdmin),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(4),
      onTap: onTap,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDestructive ? AppColors.error : null,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: isDestructive ? AppColors.error : Colors.grey.shade400),
      ),
    );
  }
}
