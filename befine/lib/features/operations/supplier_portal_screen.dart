import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

/// A dedicated dashboard for supplier-role users showing their
/// assigned stores and related transactions (invoices).
class SupplierPortalScreen extends StatefulWidget {
  const SupplierPortalScreen({super.key});

  @override
  State<SupplierPortalScreen> createState() => _SupplierPortalScreenState();
}

class _SupplierPortalScreenState extends State<SupplierPortalScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String _supplierName = '';
  String _storeName = '';
  List<Map<String, dynamic>> _transactions = [];
  double _totalOwed = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('full_name, company_id, store_id')
          .eq('id', user.id)
          .single();

      _supplierName = profile['full_name'] as String? ?? 'مورد';
      final companyId = profile['company_id'] as String;
      final storeId = profile['store_id'] as String?;

      // Get store name
      if (storeId != null) {
        try {
          final store = await _supabase.from('locations').select('name').eq('id', storeId).single();
          _storeName = store['name'] as String? ?? '';
        } catch (_) {}
      }

      // Get transactions (imports) related to this company
      final txData = await _supabase
          .from('transactions')
          .select('id, type, total_amount, created_at, notes, locations(name)')
          .eq('company_id', companyId)
          .inFilter('type', ['import', 'export'])
          .order('created_at', ascending: false)
          .limit(50);

      double totalOwed = 0;
      for (final tx in txData) {
        final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0;
        if (tx['type'] == 'import') totalOwed += amount;
      }

      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(txData);
          _totalOwed = totalOwed;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Supplier portal error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.95),
              Colors.orange.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('مرحباً، $_supplierName', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                if (_storeName.isNotEmpty)
                                  Text('المتجر المعين: $_storeName', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedGlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, color: Colors.orange, size: 32),
                                  const SizedBox(height: 8),
                                  Text('${_transactions.length}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                                  const Text('عدد الحركات', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedGlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 32),
                                  const SizedBox(height: 8),
                                  Text('${_totalOwed.toStringAsFixed(0)} د', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
                                  const Text('إجمالي الواردات', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Transactions list
                      Text('سجل الحركات', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_transactions.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                const Text('لا توجد حركات مسجلة بعد', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_transactions.length, (i) {
                          final tx = _transactions[i];
                          final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0;
                          final isImport = tx['type'] == 'import';
                          final date = DateTime.tryParse(tx['created_at'] ?? '') ?? DateTime.now();
                          final locName = (tx['locations'] as Map?)?['name'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AnimatedGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isImport ? Colors.green : Colors.red).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isImport ? Icons.download_rounded : Icons.upload_rounded,
                                      color: isImport ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isImport ? 'وارد' : 'صادر', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$locName • ${date.day}/${date.month}/${date.year}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${amount.toStringAsFixed(0)} د',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isImport ? Colors.green : Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
