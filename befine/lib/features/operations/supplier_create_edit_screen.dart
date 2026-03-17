import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/error/exceptions.dart' hide AuthException;
import '../../ui/widgets/animated_glass_card.dart';
import 'data/operations_repository.dart';

class SupplierCreateEditScreen extends StatefulWidget {
  final String? supplierId;

  const SupplierCreateEditScreen({super.key, this.supplierId});

  @override
  State<SupplierCreateEditScreen> createState() => _SupplierCreateEditScreenState();
}

class _SupplierCreateEditScreenState extends State<SupplierCreateEditScreen> {
  final _supabase = Supabase.instance.client;
  late final OperationsRepository _repo;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _warehouses = [];
  String? _selectedWarehouseId;

  bool get _isEdit => widget.supplierId != null;

  @override
  void initState() {
    super.initState();
    _repo = OperationsRepository(_supabase);
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      _warehouses = await _repo.getWarehouses();

      if (_isEdit) {
        final id = widget.supplierId!;
        final profile = await _supabase
            .from('profiles')
            .select('id, full_name, phone_number')
            .eq('id', id)
            .single();

        _nameCtrl.text = profile['full_name'] as String? ?? '';
        _phoneCtrl.text = profile['phone_number'] as String? ?? '';

        final loc = await _supabase
            .from('profile_locations')
            .select('location_id')
            .eq('profile_id', id)
            .maybeSingle();
        _selectedWarehouseId = loc?['location_id'] as String?;
      } else {
        _selectedWarehouseId = _warehouses.isNotEmpty ? _warehouses.first['id'] as String : null;
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('فشل التحضير: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWarehouseId == null) {
      _showError('اختر المخزن');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final id = widget.supplierId!;
        await _supabase.from('profiles').update({
          'full_name': _nameCtrl.text.trim(),
          'phone_number': _phoneCtrl.text.trim(),
        }).eq('id', id);

        await _supabase.from('profile_locations').delete().eq('profile_id', id);
        await _supabase.from('profile_locations').insert({
          'profile_id': id,
          'location_id': _selectedWarehouseId,
        });
      } else {
        final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
        final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        if (serviceRoleKey.isEmpty || supabaseUrl.isEmpty) {
          throw ServerException('تأكد من ضبط مفتاح الخدمة ورابط Supabase في ملف .env');
        }
        
        final adminClient = SupabaseClient(supabaseUrl, serviceRoleKey);
        final companyId = await _repo.getCurrentCompanyIdOrThrow();

        final authRes = await adminClient.auth.admin.createUser(AdminUserAttributes(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          emailConfirm: true,
        ));

        if (authRes.user == null) throw ServerException('فشل إنشاء حساب المستخدم');

        final newUserId = authRes.user!.id;

        await adminClient.from('profiles').upsert({
          'id': newUserId,
          'company_id': companyId,
          'full_name': _nameCtrl.text.trim(),
          'role': 'supplier',
          'phone_number': _phoneCtrl.text.trim(),
        });

        await adminClient.from('profile_locations').insert({
          'profile_id': newUserId,
          'location_id': _selectedWarehouseId,
        });

        adminClient.dispose();
      }

      if (!mounted) return;
      context.pop(true);
    } on AuthException catch (e) {
      _showError('خطأ: ${e.message}');
    } on PostgrestException catch (e) {
      _showError('خطأ قاعدة بيانات: ${e.message}');
    } on ServerException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('فشل الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'تعديل مورد' : 'إضافة مورد جديد';
    final theme = Theme.of(context);

    return Scaffold(
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildAppBar(context, title),
                    const SizedBox(height: 10),
                    AnimatedGlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('المعلومات الأساسية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 20),
                            _buildTextField(controller: _nameCtrl, label: 'اسم المورد الكامل', icon: Icons.person_outline, validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null),
                            const SizedBox(height: 16),
                            _buildTextField(controller: _phoneCtrl, label: 'رقم الهاتف', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                            const SizedBox(height: 24),
                            const Text('تخصيص الموقع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            _buildDropdown(),
                            if (!_isEdit) ...[
                              const SizedBox(height: 24),
                              const Text('بيانات الوصول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),
                              _buildTextField(controller: _emailCtrl, label: 'البريد الإلكتروني', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'بريد غير صالح' : null),
                              const SizedBox(height: 16),
                              _buildTextField(controller: _passwordCtrl, label: 'كلمة المرور', icon: Icons.lock_outline, obscureText: true, validator: (v) => (v == null || v.length < 6) ? 'ضعيفة' : null),
                            ],
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
                                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ بيانات المورد', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context), style: IconButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.all(12))),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool obscureText = false, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedWarehouseId,
          decoration: const InputDecoration(border: InputBorder.none, labelText: 'المخزن المرتبط'),
          items: _warehouses.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] as String? ?? ''))).toList(),
          onChanged: (v) => setState(() => _selectedWarehouseId = v),
        ),
      ),
    );
  }
}

