import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
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

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          body: isDesktop ? _buildDesktop(context, isDark) : _buildMobile(context, isDark),
        );
      },
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'store_owner': return 'صاحب متجر';
      case 'supplier': return 'مورد';
      case 'warehouse_manager': return 'مدير مخزن';
      default: return role ?? 'غير محدد';
    }
  }

  Widget _buildAvatar() {
    return Container(
      width: 120,
      height: 120,
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
          style: GoogleFonts.manrope(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          _profile?['full_name'] as String? ?? 'المستخدم',
          style: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Text(
            _roleLabel(_profile?['role'] as String?),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final user = _supabase.auth.currentUser;
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('معلومات الحساب', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _InfoRow(icon: Icons.email_outlined, label: 'البريد الإلكتروني', value: user?.email ?? 'غير متوفر'),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.phone_outlined, label: 'رقم الهاتف', value: _profile?['phone_number'] as String? ?? 'غير محدد'),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.badge_outlined, label: 'الصلاحية', value: _roleLabel(_profile?['role'] as String?)),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(4),
      borderRadius: 20,
      onTap: _signOut,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.logout_rounded, color: AppColors.error),
        ),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.manrope(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.error),
      ),
    );
  }

  Widget _buildMobile(BuildContext context, bool isDark) {
    return Column(
      children: [
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
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Text('الملف الشخصي', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 24),
                    Center(child: _buildAvatar()),
                    const SizedBox(height: 20),
                    Center(child: _buildUserInfo()),
                    const SizedBox(height: 48),
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                    const SizedBox(height: 100), // spacing for bottom nav
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context, bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الملف الشخصي', style: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 48),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Side
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildAvatar(),
                      const SizedBox(height: 24),
                      _buildUserInfo(),
                    ],
                  ),
                ),
                const SizedBox(width: 64),
                // Details Side
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 32),
                      _buildLogoutButton(),
                    ],
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
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
              Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}
