import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  void _openContactAdmin(BuildContext context, String planName, String price) {
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('خطط الاشتراك', style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Text(
                'الترقية إلى خطة أفضل',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'احصل على المزيد من المتاجر والمخازن والمميزات',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

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
                buttonText: 'تواصل للترقية الآن',
                onPressed: () => _openContactAdmin(context, 'الاحترافي', '\$50/شهر'),
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
                buttonText: 'تواصل للترقية الآن',
                onPressed: () => _openContactAdmin(context, 'الذهبي', '\$150/شهر'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
                      child: Text(buttonText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
        title: Text('ترقية إلى $planName', style: const TextStyle(fontWeight: FontWeight.bold)),
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

                // Contact
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
                        'سيتم تفعيل خطتك خلال دقائق بعد التأكد من الدفع',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final message = Uri.encodeComponent(
                              'مرحباً، شركتي ترغب بالترقية إلى الخطة $planName بسعر $price\nيرجى تزويدي بطرق الدفع المتاحة.',
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
