import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';
import 'invoice_view.dart';

/// Sales history screen showing all past sales with invoice viewing.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _sales = [];

  @override
  void initState() {
    super.initState();
    _fetchSales();
  }

  Future<void> _fetchSales() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final companyId = profile['company_id'];

      final data = await _supabase
          .from('transactions')
          .select('id, total_amount, created_at, customer_name, performed_by, location_id, locations(name), profiles!transactions_performed_by_fkey(full_name)')
          .eq('company_id', companyId)
          .eq('type', 'sale')
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) setState(() { _sales = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      debugPrint('Fetch sales error: $e');
      // Fallback without joins
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) return;
        final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
        final data = await _supabase
            .from('transactions')
            .select('id, total_amount, created_at, customer_name, performed_by, location_id')
            .eq('company_id', profile['company_id'])
            .eq('type', 'sale')
            .order('created_at', ascending: false)
            .limit(50);
        if (mounted) setState(() { _sales = List<Map<String, dynamic>>.from(data); _loading = false; });
      } catch (e2) {
        debugPrint('Fetch sales fallback error: $e2');
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _showInvoice(Map<String, dynamic> sale) async {
    // Fetch transaction items
    try {
      final items = await _supabase
          .from('transaction_items')
          .select('quantity, unit_price, product_id, products(name)')
          .eq('transaction_id', sale['id']);

      // Get company name
      final user = _supabase.auth.currentUser;
      String companyName = 'الشركة';
      if (user != null) {
        try {
          final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
          final company = await _supabase.from('companies').select('name').eq('id', profile['company_id']).single();
          companyName = company['name'] ?? 'الشركة';
        } catch (_) {}
      }

      final storeName = (sale['locations'] is Map) ? (sale['locations'] as Map)['name'] ?? '-' : '-';
      final sellerName = (sale['profiles'] is Map) ? (sale['profiles'] as Map)['full_name'] ?? '-' : '-';
      final customerName = sale['customer_name'] ?? '-';
      final date = DateTime.tryParse(sale['created_at'] ?? '') ?? DateTime.now();
      final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(date);

      // Build product info string
      String productName = '-';
      int totalQty = 0;
      double unitPrice = 0;
      if (items.isNotEmpty) {
        final names = <String>[];
        for (final item in items) {
          final pName = (item['products'] is Map) ? (item['products'] as Map)['name'] ?? '' : 'منتج';
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          names.add('$pName (×$qty)');
          totalQty += qty;
          unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
        }
        productName = names.join('، ');
      }

      if (!mounted) return;

      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InvoiceView(invoiceData: {
          'companyName': companyName,
          'storeName': storeName,
          'sellerName': sellerName,
          'customerName': customerName,
          'productName': productName,
          'quantity': totalQty,
          'unitPrice': unitPrice,
          'totalAmount': (sale['total_amount'] as num?)?.toDouble() ?? 0,
          'dateTime': dateStr,
        }),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الفاتورة: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المبيعات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 20),
                      const Text('لا توجد مبيعات بعد', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchSales,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sales.length,
                    itemBuilder: (ctx, i) {
                      final sale = _sales[i];
                      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
                      final date = DateTime.tryParse(sale['created_at'] ?? '') ?? DateTime.now();
                      final customerName = sale['customer_name'] as String?;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedGlassCard(
                          onTap: () => _showInvoice(sale),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.receipt_rounded, color: AppColors.success, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName != null && customerName.isNotEmpty ? customerName : 'عميل',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('yyyy/MM/dd HH:mm').format(date),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${amount.toStringAsFixed(0)} د',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success)),
                                  const SizedBox(height: 4),
                                  const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
