import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

class EmployeeInvitesScreen extends StatefulWidget {
  const EmployeeInvitesScreen({super.key});

  @override
  State<EmployeeInvitesScreen> createState() => _EmployeeInvitesScreenState();
}

class _EmployeeInvitesScreenState extends State<EmployeeInvitesScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _invitations = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'] as String;

      // ─── 1. Load Invitations ───
      try {
        final invData = await _supabase
            .from('company_invitations')
            .select('*, locations!company_invitations_store_id_fkey(name)')
            .eq('company_id', _companyId!)
            .order('created_at', ascending: false);
        _invitations = List<Map<String, dynamic>>.from(invData);
      } catch (e) {
        debugPrint('Error loading invites: $e');
      }

      // ─── 2. Load Employees ───
      try {
        final empData = await _supabase
            .from('profiles')
            .select('id, full_name, role, custom_role_name, phone_number, created_at, locations!profiles_store_id_fkey(name)')
            .eq('company_id', _companyId!)
            .order('created_at', ascending: false);
        _employees = List<Map<String, dynamic>>.from(empData);
      } catch (e) {
        debugPrint('Error loading employees: $e');
      }

      // ─── 3. Load Stores (Needed for Dropdowns) ───
      try {
        final storeData = await _supabase
            .from('locations')
            .select('id, name')
            .eq('company_id', _companyId!)
            .eq('type', 'store')
            .order('name');
        _stores = List<Map<String, dynamic>>.from(storeData);
      } catch (e) {
        debugPrint('Error loading stores: $e');
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Base error in _loadData: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Invite Employee Dialog (with Store/Role Assignment) ───
  void _showInviteDialog() {
    final emailCtrl = TextEditingController();
    String selectedRole = 'cashier';
    final customRoleCtrl = TextEditingController();
    String? selectedStoreId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('دعوة موظف جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    hintText: 'employee@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'الصلاحية',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cashier', child: Text('كاشير')),
                    DropdownMenuItem(value: 'store_manager', child: Text('مدير متجر')),
                    DropdownMenuItem(value: 'warehouse_worker', child: Text('موظف مخصص')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                if (selectedRole == 'warehouse_worker') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: customRoleCtrl,
                    decoration: InputDecoration(
                      labelText: 'المسمى الوظيفي المخصص',
                      hintText: 'مثال: مسؤول جودة المستودع',
                      prefixIcon: const Icon(Icons.edit_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStoreId,
                  decoration: InputDecoration(
                    labelText: 'تنسيب إلى متجر (اختياري)',
                    prefixIcon: const Icon(Icons.store_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('بدون متجر محدد')),
                    ..._stores.map((s) => DropdownMenuItem<String>(
                          value: s['id'] as String,
                          child: Text(s['name'] as String),
                        )),
                  ],
                  onChanged: (v) => setDialogState(() => selectedStoreId = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'ملاحظة: الموظف سيصله رابط أو يقوم بإنشاء حساب باستخدام بريده وسينضم للشركة تلقائياً بهذه الصلاحيات.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
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
                if (emailCtrl.text.trim().isEmpty) {
                  _showError('الرجاء كتابة البريد الإلكتروني');
                  return;
                }
                try {
                  await _supabase.from('company_invitations').insert({
                    'company_id': _companyId,
                    'invited_email': emailCtrl.text.trim(),
                    'role': selectedRole,
                    'custom_role_name': selectedRole == 'warehouse_worker' ? customRoleCtrl.text.trim() : null,
                    'store_id': selectedStoreId,
                    'invited_by': _supabase.auth.currentUser!.id,
                  });

                  await _supabase.from('audit_logs').insert({
                    'company_id': _companyId,
                    'user_id': _supabase.auth.currentUser!.id,
                    'action': 'employee_invited',
                    'entity_type': 'invitation',
                    'details': {
                      'email': emailCtrl.text.trim(),
                      'role': selectedRole,
                      'custom_name': customRoleCtrl.text.trim(),
                      'store_id': selectedStoreId,
                    },
                  });

                  Navigator.pop(ctx);
                  _loadData();
                  _showSuccess('تم إرسال الدعوة للموظف!');
                } catch (e) {
                  _showError('حدث خطأ أثناء الإرسال: $e');
                }
              },
              child: const Text('إرسال الدعوة'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Direct Add Employee Dialog ───
  void _showAddEmployeeDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'cashier';
    final customRoleCtrl = TextEditingController();
    String? selectedStoreId;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إضافة موظف مباشر', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'الصلاحية',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cashier', child: Text('كاشير')),
                    DropdownMenuItem(value: 'store_manager', child: Text('مدير متجر')),
                    DropdownMenuItem(value: 'warehouse_worker', child: Text('موظف مخصص')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                if (selectedRole == 'warehouse_worker') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customRoleCtrl,
                    decoration: InputDecoration(
                      labelText: 'المسمى الوظيفي المخصص',
                      prefixIcon: const Icon(Icons.edit_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStoreId,
                  decoration: InputDecoration(
                    labelText: 'تنسيب إلى متجر (اختياري)',
                    prefixIcon: const Icon(Icons.store_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('بدون متجر محدد')),
                    ..._stores.map((s) => DropdownMenuItem<String>(
                          value: s['id'] as String,
                          child: Text(s['name'] as String),
                        )),
                  ],
                  onChanged: (v) => setDialogState(() => selectedStoreId = v),
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
              onPressed: saving ? null : () async {
                if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passwordCtrl.text.length < 6) {
                  _showError('الرجاء تعبئة الاسم والبريد وكلمة مرور (6+ حروف)');
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
                  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
                  if (serviceRoleKey.isEmpty || supabaseUrl.isEmpty) {
                    throw Exception('تأكد من ضبط مفتاح الخدمة ورابط Supabase في ملف .env');
                  }
                  
                  final adminClient = SupabaseClient(supabaseUrl, serviceRoleKey);
                  
                  final authRes = await adminClient.auth.admin.createUser(AdminUserAttributes(
                    email: emailCtrl.text.trim(),
                    password: passwordCtrl.text,
                    emailConfirm: true,
                  ));

                  if (authRes.user == null) throw Exception('فشل إنشاء حساب الموظف');

                  await adminClient.from('profiles').upsert({
                    'id': authRes.user!.id,
                    'company_id': _companyId,
                    'full_name': nameCtrl.text.trim(),
                    'phone_number': phoneCtrl.text.trim(),
                    'role': selectedRole,
                    'custom_role_name': selectedRole == 'warehouse_worker' ? customRoleCtrl.text.trim() : null,
                    'store_id': selectedStoreId,
                  });
                  
                  adminClient.dispose();

                  await _supabase.from('audit_logs').insert({
                    'company_id': _companyId,
                    'user_id': _supabase.auth.currentUser!.id,
                    'action': 'employee_created_directly',
                    'entity_type': 'profile',
                    'details': {
                      'email': emailCtrl.text.trim(),
                      'role': selectedRole,
                      'store_id': selectedStoreId,
                    },
                  });

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadData();
                  _showSuccess('تم إضافة الموظف بنجاح!');
                } catch (e) {
                  _showError('حدث خطأ: $e');
                  setDialogState(() => saving = false);
                }
              },
              child: saving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('إضافة الموظف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelInvitation(String invitationId) async {
    try {
      await _supabase
          .from('company_invitations')
          .update({'status': 'cancelled'})
          .eq('id', invitationId);
      _loadData();
    } catch (e) {
      _showError('حدث خطأ: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  String _roleLabel(String? role, String? customName) {
    if (role == 'warehouse_worker' && customName != null && customName.isNotEmpty) {
      return customName;
    }
    switch (role) {
      case 'admin': return 'مدير';
      case 'store_manager': return 'مدير متجر';
      case 'cashier': return 'كاشير';
      case 'warehouse_worker': return 'موظف مخصص';
      case 'supplier': return 'مورد';
      default: return role ?? 'غير محدد';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return AppColors.success;
      case 'expired': return Colors.grey;
      case 'cancelled': return AppColors.error;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'accepted': return 'مقبولة';
      case 'expired': return 'منتهية';
      case 'cancelled': return 'ملغاة';
      default: return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        title: const Text('إدارة الموظفين', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الموظفون', icon: Icon(Icons.people_rounded)),
            Tab(text: 'الدعوات', icon: Icon(Icons.mail_outline_rounded)),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'invite_or_add',
        onPressed: _tabController.index == 0 ? _showAddEmployeeDialog : _showInviteDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(_tabController.index == 0 ? Icons.person_add_alt_1_rounded : Icons.mail_outline_rounded),
        label: Text(_tabController.index == 0 ? 'إضافة موظف' : 'دعوة موظف'),
      ),
      extendBodyBehindAppBar: true,
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
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Employees
                    _employees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('لا يوجد موظفون', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 180),
                            itemCount: _employees.length,
                            itemBuilder: (context, index) {
                              final emp = _employees[index];
                              final storeName = (emp['locations'] as Map?)?['name'] as String?;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AnimatedGlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryVariant]),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (emp['full_name'] as String? ?? 'م').substring(0, 1),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              emp['full_name'] as String? ?? 'موظف',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    _roleLabel(emp['role'] as String?, emp['custom_role_name'] as String?),
                                                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                if (storeName != null) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.store_rounded, size: 14, color: Colors.grey.shade500),
                                                  const SizedBox(width: 4),
                                                  Text(storeName, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (emp['phone_number'] != null)
                                        Icon(Icons.phone, size: 18, color: Colors.grey.shade400),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                    // TAB 2: Invitations
                    _invitations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mail_outline, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('لا توجد دعوات', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 180),
                            itemCount: _invitations.length,
                            itemBuilder: (context, index) {
                              final inv = _invitations[index];
                              final status = inv['status'] as String? ?? 'pending';
                              final storeName = (inv['locations'] as Map?)?['name'] as String?;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AnimatedGlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(Icons.mail_rounded, color: _statusColor(status)),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inv['invited_email'] as String? ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(status).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    _statusLabel(status),
                                                    style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(_roleLabel(inv['role'] as String?, inv['custom_role_name'] as String?), 
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                                if (storeName != null) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.store_rounded, size: 12, color: Colors.grey.shade500),
                                                  const SizedBox(width: 2),
                                                  Text(storeName, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (status == 'pending')
                                        IconButton(
                                          onPressed: () => _cancelInvitation(inv['id'] as String),
                                          icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                                          tooltip: 'إلغاء الدعوة',
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
        ),
      ),
    );
  }
}
