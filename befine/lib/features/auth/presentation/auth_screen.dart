import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../application/auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _companyNameController = TextEditingController();

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Use the authProvider notifier so the state is always in sync
    await ref.read(authProvider.notifier).signIn(email, password);

    final authState = ref.read(authProvider);
    if (authState.error != null) {
      _showError(authState.error!);
      return;
    }

    if (authState.isAuthenticated && mounted) {
      context.go('/dashboard');
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();
    final companyName = _companyNameController.text.trim();

    // 1. Check if there is an invitation for this email
    Map<String, dynamic>? invitation;
    try {
      final invData = await _supabase
          .from('company_invitations')
          .select('*')
          .eq('invited_email', email)
          .eq('status', 'pending')
          .maybeSingle();
      invitation = invData;
    } catch (_) {}

    // 2. Create the auth user
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      _showError('فشل إنشاء الحساب. حاول مرة أخرى.');
      return;
    }

    if (invitation != null) {
      // Join existing company via invitation
      final invCompanyId = invitation['company_id'] as String;
      final invRole = invitation['role'] as String? ?? 'cashier';
      final invStoreId = invitation['store_id'] as String?;
      final invCustomRole = invitation['custom_role_name'] as String?;

      await _supabase.from('profiles').insert({
        'id': user.id,
        'company_id': invCompanyId,
        'full_name': fullName.isNotEmpty ? fullName : email.split('@').first,
        'role': invRole,
        if (invStoreId != null) 'store_id': invStoreId,
        if (invCustomRole != null) 'custom_role_name': invCustomRole,
      });

      // Mark invitation as accepted
      await _supabase
          .from('company_invitations')
          .update({'status': 'accepted'})
          .eq('id', invitation['id']);

      // Audit log
      await _supabase.from('audit_logs').insert({
        'company_id': invCompanyId,
        'user_id': user.id,
        'action': 'employee_joined',
        'entity_type': 'profile',
        'details': {'email': email, 'role': invRole, 'store_id': invStoreId},
      });

      _showSuccess('تم الانضمام إلى الشركة بنجاح!');
      if (mounted) context.go('/dashboard');
    } else {
      // Create a new company
      if (companyName.isEmpty) {
        _showError('أدخل اسم الشركة');
        return;
      }

      // Extract email domain for auto-join
      final emailDomain = email.contains('@') ? email.split('@').last : null;

      final companyId = const Uuid().v4();

      await _supabase
          .from('companies')
          .insert({
            'id': companyId,
            'name': companyName,
            'email_domain': emailDomain,
          });

      // Create the admin profile linked to the company
      await _supabase.from('profiles').insert({
        'id': user.id,
        'company_id': companyId,
        'full_name': fullName,
        'role': 'admin',
      });

      // Audit log
      await _supabase.from('audit_logs').insert({
        'company_id': companyId,
        'user_id': user.id,
        'action': 'company_created',
        'entity_type': 'company',
        'entity_id': companyId,
        'details': {'name': companyName},
      });

      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _signIn();
      } else {
        await _signUp();
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryVariant],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isLogin ? 'مرحباً بعودتك' : 'إنشاء مساحة عمل جديدة',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'سجّل دخولك لإدارة مخازنك ومبيعاتك'
                        : 'سجّل شركتك للبدء باستخدام النظام\nأو سجّل بدعوة من شركتك',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Registration-only fields
                        if (!_isLogin) ...[
                          _buildField(
                            controller: _companyNameController,
                            label: 'اسم الشركة',
                            hint: 'اتركه فارغاً إذا لديك دعوة',
                            icon: Icons.business,
                            validator: null, // Optional — invitation-based users don't need this
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: _fullNameController,
                            label: 'الاسم الكامل',
                            hint: 'محمد أحمد',
                            icon: Icons.person,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _buildField(
                          controller: _emailController,
                          label: 'البريد الإلكتروني',
                          hint: 'name@company.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.isEmpty) return 'مطلوب';
                            if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _passwordController,
                          label: 'كلمة المرور',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'مطلوب';
                            if (v.length < 6) return 'على الأقل 6 أحرف';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    _isLogin ? 'تسجيل الدخول' : 'إنشاء مساحة العمل',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? 'ليس لديك حساب؟ ' : 'لديك حساب بالفعل؟ ',
                              style: theme.textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _isLogin = !_isLogin;
                                _formKey.currentState?.reset();
                              }),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                              child: Text(
                                _isLogin ? 'إنشاء حساب' : 'تسجيل الدخول',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
    );
  }
}
