import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _supabase = Supabase.instance.client;
  int _currentStep = 0; // 0=welcome, 1=plans, 2=store, 3=complete
  bool _isLoading = false;

  // Store creation
  final _storeNameCtrl = TextEditingController();
  String? _selectedWarehouseId;
  List<Map<String, dynamic>> _warehouses = [];

  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadInitData();
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitData() async {
    try {
      final user = _supabase.auth.currentUser!;
      final profile = await _supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'] as String;

      // Load warehouses (own + super admin's)
      final whData = await _supabase
          .from('locations')
          .select('id, name, address, max_stores, company_id')
          .eq('type', 'warehouse')
          .or('company_id.eq.$_companyId,company_id.eq.00000000-0000-0000-0000-000000000001');

      // Load stores to count reserved slots
      final storeData = await _supabase
          .from('locations')
          .select('parent_id')
          .eq('type', 'store')
          .not('parent_id', 'is', 'null');

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
        setState(() {
          _warehouses = whList;
        });
      }
    } catch (e) {
      debugPrint('Error loading init data: $e');
    }
  }

  Future<void> _selectFreePlan() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('companies').update({
        'subscription_plan': 'free',
        'max_warehouses': 0,
        'max_stores': 1,
      }).eq('id', _companyId!);
      setState(() {
        _currentStep = 2;
        _isLoading = false;
      });
    } catch (e) {
      _showError('حدث خطأ: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createStore() async {
    if (_storeNameCtrl.text.trim().isEmpty) {
      _showError('أدخل اسم المتجر');
      return;
    }
    if (_selectedWarehouseId == null) {
      _showError('اختر المخزن الذي تريد الانتساب إليه');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.from('locations').insert({
        'company_id': _companyId,
        'parent_id': _selectedWarehouseId,
        'name': _storeNameCtrl.text.trim(),
        'type': 'store',
      });

      await _supabase.from('audit_logs').insert({
        'company_id': _companyId,
        'user_id': _supabase.auth.currentUser!.id,
        'action': 'store_created',
        'entity_type': 'location',
        'details': {
          'name': _storeNameCtrl.text.trim(),
          'warehouse_id': _selectedWarehouseId,
        },
      });

      await _supabase
          .from('companies')
          .update({'onboarding_completed': true})
          .eq('id', _companyId!);

      setState(() => _currentStep = 3);
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openContactAdmin(String planName, String price) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ContactAdminScreen(planName: planName, price: price),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                // Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final isActive = i <= _currentStep;
                    return Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isActive ? 32 : 12,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (i < 3) const SizedBox(width: 6),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 40),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _buildStep(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildPlansStep();
      case 2:
        return _buildStoreStep();
      case 3:
        return _buildCompleteStep();
      default:
        return const SizedBox();
    }
  }

  // ─────────────── Step 0: Welcome ───────────────
  Widget _buildWelcomeStep() {
    return Column(
      key: const ValueKey('welcome'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryVariant],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 30),
            ],
          ),
          child: const Icon(Icons.rocket_launch_rounded, size: 56, color: Colors.white),
        ),
        const SizedBox(height: 32),
        const Text(
          'مرحباً بك في مساحة عملك!',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'سنساعدك الآن في اختيار الخطة المناسبة\nوإعداد متجرك الأول',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade500, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('بدء الإعداد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ─────────────── Step 1: Plans ───────────────
  Widget _buildPlansStep() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      key: const ValueKey('plans'),
      child: Column(
        children: [
          const Text(
            'اختر خطتك',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'اختر الباقة التي تناسب احتياجاتك',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // ─── Free Plan ───
          _PlanCard(
            title: 'مجاني',
            subtitle: 'للبدايات الصغيرة',
            price: 'مجاني',
            priceSubtitle: 'إلى الأبد',
            icon: Icons.storefront_rounded,
            color: Colors.teal,
            isDark: isDark,
            isPopular: false,
            features: const [
              'متجر واحد فقط',
              'ربط بأحد المخازن المتاحة',
              'إدارة المنتجات والمبيعات',
              'تقارير أساسية',
              'دعم عبر البريد الإلكتروني',
            ],
            buttonText: 'ابدأ مجاناً',
            onPressed: _isLoading ? null : _selectFreePlan,
            isLoading: _isLoading,
          ),

          const SizedBox(height: 16),

          // ─── Pro Plan ───
          _PlanCard(
            title: 'احترافي',
            subtitle: 'للأعمال المتوسطة',
            price: '\$50',
            priceSubtitle: '/ شهرياً',
            icon: Icons.diamond_rounded,
            color: Colors.blue.shade700,
            isDark: isDark,
            isPopular: true,
            features: const [
              'حتى 6 متاجر',
              'ربط بأي مخزن في النظام',
              'دعم فني سريع خلال 24 ساعة',
              'تقارير متقدمة وتحليلات',
              'إدارة صلاحيات الموظفين',
              'إشعارات فورية للمخزون',
            ],
            buttonText: 'اشترك الآن',
            onPressed: () => _openContactAdmin('الاحترافي', '\$50/شهر'),
          ),

          const SizedBox(height: 16),

          // ─── Gold Plan ───
          _PlanCard(
            title: 'ذهبي',
            subtitle: 'للمؤسسات الكبيرة',
            price: '\$150',
            priceSubtitle: '/ شهرياً',
            icon: Icons.workspace_premium_rounded,
            color: Colors.amber.shade700,
            isDark: isDark,
            isPopular: false,
            features: const [
              'متاجر غير محدودة',
              'إنشاء مخازن خاصة بك',
              'ربط بأي مخزن في النظام',
              'دعم فني متميز على مدار الساعة',
              'تقارير شاملة وتصدير البيانات',
              'API للتكامل مع أنظمة خارجية',
              'مدير حساب مخصص',
              'نسخ احتياطي يومي متقدم',
            ],
            buttonText: 'اشترك الآن',
            onPressed: () => _openContactAdmin('الذهبي', '\$150/شهر'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────── Step 2: Store Creation ───────────────
  Widget _buildStoreStep() {
    return SingleChildScrollView(
      key: const ValueKey('store'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إنشاء متجرك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('أنشئ متجرك الأول واختر المخزن المرجعي', style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 28),

          AnimatedGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _storeNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المتجر',
                    hintText: 'مثال: متجر الشارع الرئيسي',
                    prefixIcon: const Icon(Icons.store_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: _selectedWarehouseId,
                  isExpanded: true,
                  itemHeight: 70,
                  decoration: InputDecoration(
                    labelText: 'اختر المخزن المرجعي',
                    prefixIcon: const Icon(Icons.warehouse_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: _warehouses.map((wh) {
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
                  onChanged: (v) => setState(() => _selectedWarehouseId = v),
                  hint: _warehouses.isEmpty
                      ? const Text('لا توجد مخازن متاحة - تواصل مع المدير')
                      : const Text('اختر مخزناً'),
                ),
              ],
            ),
          ),

          if (_warehouses.isEmpty) ...[
            const SizedBox(height: 16),
            AnimatedGlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orange.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد مخازن متاحة حالياً. يرجى التواصل مع مدير المنصة لإنشاء مخزن.',
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_isLoading || _warehouses.isEmpty) ? null : _createStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('إنشاء المتجر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Step 3: Complete ───────────────
  Widget _buildCompleteStep() {
    return Column(
      key: const ValueKey('complete'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.success, Color(0xFF00C853)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.success.withOpacity(0.3), blurRadius: 30),
            ],
          ),
          child: const Icon(Icons.check_rounded, size: 56, color: Colors.white),
        ),
        const SizedBox(height: 32),
        const Text(
          'تم الإعداد بنجاح! 🎉',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'مساحة عملك جاهزة الآن\nيمكنك البدء بإضافة المنتجات ودعوة الموظفين',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade500, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('الذهاب إلى لوحة التحكم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ─────────────── Plan Card Widget ───────────────
class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String priceSubtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool isPopular;
  final List<String> features;
  final String buttonText;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.priceSubtitle,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.isPopular,
    required this.features,
    required this.buttonText,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedGlassCard(
          padding: EdgeInsets.zero,
          child: Container(
            decoration: isPopular
                ? BoxDecoration(
                    border: Border.all(color: color.withOpacity(0.5), width: 2),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),

                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          ' $priceSubtitle',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Features
                  ...features.map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 18, color: color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(f, style: const TextStyle(fontSize: 13.5)),
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: 24),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        shadowColor: color.withOpacity(0.4),
                      ),
                      child: isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(buttonText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Popular badge
        if (isPopular)
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Text(
                  '⭐ الأكثر شيوعاً',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────── Contact Admin Screen ───────────────
class _ContactAdminScreen extends StatelessWidget {
  final String planName;
  final String price;

  const _ContactAdminScreen({required this.planName, required this.price});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('اشتراك $planName', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.shade600,
                        Colors.orange.shade700,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 32),

                Text(
                  'ترقية إلى الخطة $planName',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'للاشتراك في هذه الخطة بسعر $price\nيرجى التواصل مع المدير العام للمنصة',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade500, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Contact via WhatsApp
                AnimatedGlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.support_agent_rounded, size: 48, color: Colors.green.shade600),
                      const SizedBox(height: 12),
                      const Text(
                        'تواصل مع الإدارة',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'سيتم تفعيل خطتك خلال 24 ساعة بعد التأكد من الدفع',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // WhatsApp Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final message = Uri.encodeComponent(
                              'مرحباً، أريد الاشتراك في الخطة $planName بسعر $price\nالرجاء تفعيل حسابي.',
                            );
                            final url = Uri.parse('https://wa.me/9647721279418?text=$message');
                            try {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 22),
                          label: const Text(
                            'تواصل عبر واتساب',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Phone Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final url = Uri.parse('tel:07721279418');
                            try {
                              await launchUrl(url);
                            } catch (_) {}
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.phone_rounded, size: 20),
                          label: const Text(
                            'اتصال هاتفي',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'العودة لاختيار خطة أخرى',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
