import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/application/auth_service.dart';
import 'data/operations_repository.dart';
import 'suppliers_screen.dart';

class OperationsScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  const OperationsScreen({super.key, this.initialTab});

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  int _getInitialIndex(bool isSupplier) {
    if (isSupplier) {
      switch (widget.initialTab) {
        case 'imports': return 0;
        case 'exports': return 1;
        case 'sales': return 2;
        default: return 0;
      }
    }

    switch (widget.initialTab) {
      case 'quick_add': return 0;
      case 'imports': return 1;
      case 'exports': return 2;
      case 'suppliers': return 3;
      case 'tasks': return 4;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final isSupplier = userState.user?.role == 'supplier';
    
    final int tabsCount = isSupplier ? 3 : 6;
    
    return DefaultTabController(
      length: tabsCount,
      initialIndex: _getInitialIndex(isSupplier),
      child: Scaffold(
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
          child: Column(
            children: [
              _buildHeader(context, isSupplier),
              Expanded(
                child: TabBarView(
                  children: isSupplier 
                    ? [
                        const _TransactionListTab(type: 'import'),
                        const _TransactionListTab(type: 'export'),
                        const _TransactionListTab(type: 'sale'),
                      ]
                    : [
                        _QuickAddTab(),
                        const _TransactionListTab(type: 'import'),
                        const _TransactionListTab(type: 'export'),
                        const _TransactionListTab(type: 'sale'),
                        _SuppliersTab(),
                        _TasksTab(),
                      ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSupplier) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('العمليات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () {},
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurface,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelColor: Colors.grey,
            tabs: isSupplier 
              ? const [
                  Tab(text: 'الواردات'),
                  Tab(text: 'الصادرات'),
                  Tab(text: 'المبيعات'),
                ]
              : const [
                  Tab(text: 'إضافة سريعة'),
                  Tab(text: 'الواردات'),
                  Tab(text: 'الصادرات'),
                  Tab(text: 'المبيعات'),
                  Tab(text: 'الموردون'),
                  Tab(text: 'المهام'),
                ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _QuickAddTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('اختصارات الإضافة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _QuickAddCard(
          icon: Icons.inventory_2,
          title: 'منتج جديد',
          subtitle: 'أضف منتجاً لكتالوجك',
          color: AppColors.primary,
          onTap: () => context.go('/inventory'),
        ),
        _QuickAddCard(
          icon: Icons.download_rounded,
          title: 'وارد جديد',
          subtitle: 'سجّل بضاعة واردة من مورد',
          color: Colors.blue,
          onTap: () => context.push('/operations/transaction/create?type=import'),
        ),
        _QuickAddCard(
          icon: Icons.upload_rounded,
          title: 'صادر جديد',
          subtitle: 'سجّل بضاعة صادرة لعميل',
          color: Colors.orange,
          onTap: () => context.push('/operations/transaction/create?type=export'),
        ),
        _QuickAddCard(
          icon: Icons.person_add_rounded,
          title: 'مورد جديد',
          subtitle: 'سجّل بيانات مورد جديد',
          color: Colors.teal,
          onTap: () => context.push('/operations/suppliers/create'),
        ),
      ],
    );
  }
}

class _QuickAddCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _QuickAddCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _TransactionListTab extends StatefulWidget {
  final String type;
  const _TransactionListTab({required this.type});

  @override
  State<_TransactionListTab> createState() => _TransactionListTabState();
}

class _TransactionListTabState extends State<_TransactionListTab> {
  late final OperationsRepository _repo;
  final _searchCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _repo = OperationsRepository(Supabase.instance.client);
    _future = _repo.getTransactions(type: widget.type);
  }

  void _refresh() {
    setState(() => _future = _repo.getTransactions(type: widget.type));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: AnimatedGlassCard(
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: widget.type == 'import' ? 'بحث في الواردات...' : widget.type == 'export' ? 'بحث في الصادرات...' : 'بحث في المبيعات...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () async {
                  final res = await context.push<bool>('/operations/transaction/create?type=${widget.type}');
                  if (res == true) _refresh();
                },
                icon: const Icon(Icons.add, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(16)),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}'));

              final q = _searchCtrl.text.trim();
              var items = snapshot.data ?? const [];
              if (q.isNotEmpty) {
                items = items.where((t) {
                  final id = '${t['id'] ?? ''}';
                  final loc = (t['locations'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
                  return id.contains(q) || loc.contains(q);
                }).toList();
              }

              if (items.isEmpty) return const Center(child: Text('لا توجد عمليات حالياً'));

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final t = items[i];
                    final color = widget.type == 'import' ? Colors.blue : widget.type == 'export' ? Colors.orange : AppColors.success;
                    final icon = widget.type == 'import' ? Icons.download : widget.type == 'export' ? Icons.upload : Icons.receipt_rounded;
                    final label = widget.type == 'import' ? 'وارد' : widget.type == 'export' ? 'صادر' : 'بيع';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnimatedGlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Icon(icon, color: color),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$label #${t['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text((t['locations'] as Map<String, dynamic>?)?['name']?.toString() ?? 'متجر غير معروف', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Text('${t['total_amount']} د', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
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
      ],
    );
  }
}

class _SuppliersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SuppliersScreen();
  }
}

class _TasksTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final taskNames = ['إعادة تعبئة متجر أ', 'جرد مخزن ب', 'تسليم طلبية #44', 'تحديث الأسعار', 'التحقق من الشحنة'];
    final statuses = ['pending', 'in_progress', 'completed', 'pending', 'in_progress'];
    final statusLabels = {'pending': 'معلق', 'in_progress': 'جارٍ', 'completed': 'مكتمل'};
    final colors = {'pending': Colors.orange, 'in_progress': Colors.blue, 'completed': AppColors.success};

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: taskNames.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المهام الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_task_rounded),
                  onPressed: () {}, // TODO: Navigate to create task screen
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
        
        final idx = i - 1;
        final status = statuses[idx];
        final color = colors[status]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedGlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Checkbox(value: status == 'completed', onChanged: (_) {}, activeColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(taskNames[idx], style: TextStyle(fontWeight: FontWeight.bold, decoration: status == 'completed' ? TextDecoration.lineThrough : null)),
                      Text('موظف التسليم', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(statusLabels[status]!, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
