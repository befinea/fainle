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
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSuperAdmin();
  }

  Future<void> _checkSuperAdmin() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _isSuperAdmin = profile['company_id'] == '00000000-0000-0000-0000-000000000001';
        });
      }
    } catch (_) {}
  }

  List<Tab> _getTabs(bool isSupplier) {
    if (isSupplier) {
      return const [Tab(text: 'الواردات'), Tab(text: 'الصادرات'), Tab(text: 'المبيعات')];
    }
    // Company owner / admin
    final tabs = <Tab>[
      const Tab(text: 'إضافة سريعة'),
      const Tab(text: 'الواردات'),
      const Tab(text: 'الصادرات'),
      const Tab(text: 'المبيعات'),
    ];
    if (_isSuperAdmin) tabs.add(const Tab(text: 'الموردون'));
    tabs.add(const Tab(text: 'المهام'));
    tabs.add(const Tab(text: 'السجل'));
    return tabs;
  }

  List<Widget> _getTabViews(bool isSupplier) {
    if (isSupplier) {
      return const [
        _TransactionListTab(type: 'import'),
        _TransactionListTab(type: 'export'),
        _TransactionListTab(type: 'sale'),
      ];
    }
    final views = <Widget>[
      _QuickAddTab(isSuperAdmin: _isSuperAdmin),
      const _TransactionListTab(type: 'import'),
      const _TransactionListTab(type: 'export'),
      const _TransactionListTab(type: 'sale'),
    ];
    if (_isSuperAdmin) views.add(_SuppliersTab());
    views.add(const _TasksTab());
    views.add(const _AuditLogTab());
    return views;
  }

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
      case 'sales': return 3;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final isSupplier = userState.user?.role == 'supplier';

    final tabs = _getTabs(isSupplier);
    final tabViews = _getTabViews(isSupplier);

    return DefaultTabController(
      length: tabs.length,
      initialIndex: _getInitialIndex(isSupplier).clamp(0, tabs.length - 1),
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
              SafeArea(
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
                      tabs: tabs,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              Expanded(child: TabBarView(children: tabViews)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Add Tab ───
class _QuickAddTab extends StatelessWidget {
  final bool isSuperAdmin;
  const _QuickAddTab({this.isSuperAdmin = false});

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
          onTap: () => context.go('/stores'),
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
        if (isSuperAdmin)
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

// ─── Transaction List Tab ───
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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

// ─── Suppliers Tab (Super Admin only) ───
class _SuppliersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SuppliersScreen();
  }
}

// ─── Tasks Tab (with store assignment, priority, real DB) ───
class _TasksTab extends StatefulWidget {
  const _TasksTab();

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final user = _supabase.auth.currentUser!;
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      _companyId = profile['company_id'] as String;

      final data = await _supabase
          .from('tasks')
          .select('*, profiles!tasks_assigned_to_fkey(full_name), locations!tasks_store_id_fkey(name)')
          .eq('company_id', _companyId!)
          .order('created_at', ascending: false);

      if (mounted) setState(() { _tasks = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateTaskDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'normal';
    String? selectedStoreId;
    String? selectedEmployeeId;

    // Load stores and employees
    List<Map<String, dynamic>> stores = [];
    List<Map<String, dynamic>> employees = [];
    try {
      stores = List<Map<String, dynamic>>.from(
        await _supabase.from('locations').select('id, name').eq('company_id', _companyId!).eq('type', 'store'),
      );
      employees = List<Map<String, dynamic>>.from(
        await _supabase.from('profiles').select('id, full_name, role').eq('company_id', _companyId!),
      );
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('مهمة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'عنوان المهمة',
                    prefixIcon: const Icon(Icons.task_alt_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'الوصف (اختياري)',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Priority
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: InputDecoration(
                    labelText: 'الأهمية',
                    prefixIcon: const Icon(Icons.flag_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('🟢 عادي')),
                    DropdownMenuItem(value: 'important', child: Text('🟡 هام')),
                    DropdownMenuItem(value: 'urgent', child: Text('🔴 عاجل')),
                  ],
                  onChanged: (v) => setDialogState(() => priority = v!),
                ),
                const SizedBox(height: 12),

                // Store
                DropdownButtonFormField<String>(
                  value: selectedStoreId,
                  decoration: InputDecoration(
                    labelText: 'المتجر',
                    prefixIcon: const Icon(Icons.store_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: stores.map((s) => DropdownMenuItem<String>(
                    value: s['id'] as String,
                    child: Text(s['name'] as String),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedStoreId = v),
                  hint: const Text('اختر المتجر'),
                ),
                const SizedBox(height: 12),

                // Employee
                DropdownButtonFormField<String>(
                  value: selectedEmployeeId,
                  decoration: InputDecoration(
                    labelText: 'تعيين إلى',
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: employees.map((e) => DropdownMenuItem<String>(
                    value: e['id'] as String,
                    child: Text(e['full_name'] as String? ?? 'موظف'),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedEmployeeId = v),
                  hint: const Text('اختر الموظف'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                try {
                  await _supabase.from('tasks').insert({
                    'company_id': _companyId,
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                    'priority': priority,
                    'store_id': selectedStoreId,
                    'assigned_to': selectedEmployeeId,
                    'status': 'pending',
                  });
                  Navigator.pop(ctx);
                  _loadTasks();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error));
                }
              },
              child: const Text('إنشاء المهمة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTaskStatus(Map<String, dynamic> task) async {
    final currentStatus = task['status'] as String? ?? 'pending';
    final newStatus = currentStatus == 'completed' ? 'pending' : 'completed';
    try {
      await _supabase.from('tasks').update({'status': newStatus}).eq('id', task['id']);
      _loadTasks();
    } catch (_) {}
  }

  Color _priorityColor(String? p) {
    switch (p) {
      case 'urgent': return Colors.red;
      case 'important': return Colors.orange;
      default: return Colors.green;
    }
  }

  String _priorityLabel(String? p) {
    switch (p) {
      case 'urgent': return 'عاجل';
      case 'important': return 'هام';
      default: return 'عادي';
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'in_progress': return 'جارٍ';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغي';
      default: return 'معلق';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'in_progress': return Colors.blue;
      case 'completed': return AppColors.success;
      case 'cancelled': return Colors.grey;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المهام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_task_rounded),
                onPressed: _showCreateTaskDialog,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tasks.isEmpty
              ? Center(child: Text('لا توجد مهام بعد', style: TextStyle(color: Colors.grey.shade500)))
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _tasks.length,
                    itemBuilder: (ctx, i) {
                      final task = _tasks[i];
                      final status = task['status'] as String? ?? 'pending';
                      final priority = task['priority'] as String? ?? 'normal';
                      final assignee = task['profiles'];
                      final store = task['locations'];
                      final assigneeName = assignee is Map ? (assignee['full_name'] as String? ?? '') : '';
                      final storeName = store is Map ? (store['name'] as String? ?? '') : '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedGlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Checkbox(
                                value: status == 'completed',
                                onChanged: (_) => _toggleTaskStatus(task),
                                activeColor: AppColors.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task['title'] as String? ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: status == 'completed' ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (storeName.isNotEmpty) ...[
                                          Icon(Icons.store_rounded, size: 12, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(storeName, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                          const SizedBox(width: 8),
                                        ],
                                        if (assigneeName.isNotEmpty) ...[
                                          Icon(Icons.person_rounded, size: 12, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(assigneeName, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(color: _priorityColor(priority).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text(_priorityLabel(priority), style: TextStyle(fontSize: 9, color: _priorityColor(priority), fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Audit Log Tab (inline) ───
class _AuditLogTab extends StatefulWidget {
  const _AuditLogTab();

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final user = _supabase.auth.currentUser!;
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final companyId = profile['company_id'] as String;

      final data = await _supabase
          .from('audit_logs')
          .select('*, profiles!audit_logs_user_id_fkey(full_name)')
          .eq('company_id', companyId)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) setState(() { _logs = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      debugPrint('Error loading logs: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'warehouse_created': return 'إنشاء مخزن';
      case 'store_created': return 'إنشاء متجر';
      case 'product_created': return 'إضافة منتج';
      case 'sale_completed': return 'عملية بيع';
      case 'employee_invited': return 'دعوة موظف';
      case 'employee_added_direct': return 'إضافة موظف';
      case 'company_created': return 'إنشاء شركة';
      default: return action.replaceAll('_', ' ');
    }
  }

  String _timeAgo(String createdAt) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(createdAt).toLocal());
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
      return 'منذ ${diff.inDays} يوم';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_logs.isEmpty) return Center(child: Text('لا توجد نشاطات', style: TextStyle(color: Colors.grey.shade500)));

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _logs.length,
        itemBuilder: (ctx, i) {
          final log = _logs[i];
          final action = log['action'] as String? ?? '';
          final profileData = log['profiles'];
          final userName = profileData is Map ? (profileData['full_name'] as String? ?? 'مستخدم') : 'مستخدم';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnimatedGlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_actionLabel(action), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('بواسطة: $userName', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Text(_timeAgo(log['created_at'] as String? ?? ''), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
