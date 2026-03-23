import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';
import 'invoice_view.dart';
import 'sales_history_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _currentLocationId;
  String? _currentLocationName;
  String? _sellerName;
  String? _companyName;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  /// Load seller name, location, and company info at startup.
  Future<void> _loadContext() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('full_name, store_id, company_id')
          .eq('id', user.id)
          .single();

      _sellerName = profile['full_name'] as String? ?? 'غير محدد';
      _companyId = profile['company_id'] as String?;
      String? locationId = profile['store_id'] as String?;

      // Fallback: find any location for this company
      if (locationId == null && _companyId != null) {
        final locs = await _supabase.from('locations').select('id, name').eq('company_id', _companyId!).limit(1);
        if (locs.isNotEmpty) {
          locationId = locs.first['id'] as String?;
        }
      }

      _currentLocationId = locationId;

      // Fetch location name
      if (locationId != null) {
        try {
          final loc = await _supabase.from('locations').select('name').eq('id', locationId).single();
          _currentLocationName = loc['name'] as String?;
        } catch (_) {}
      }

      // Fetch company name
      if (_companyId != null) {
        try {
          final company = await _supabase.from('companies').select('name').eq('id', _companyId!).single();
          _companyName = company['name'] as String?;
        } catch (_) {}
      }

      debugPrint('POS Context: seller=$_sellerName, location=$_currentLocationId/$_currentLocationName, company=$_companyName');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('POS _loadContext error: $e');
    }
  }

  /// Fetch stock for a product by checking each company location individually.
  /// Returns -1 if no stock records exist at all (unlimited).
  /// Returns total stock across all company locations. Returns 0 if not found.
  Future<int> _getStock(String productId) async {
    try {
      if (_companyId == null) return 0;

      final locs = await _supabase.from('locations').select('id').eq('company_id', _companyId!);
      if (locs.isEmpty) return 0;

      int total = 0;
      for (final loc in locs) {
        final locId = loc['id'] as String;
        final data = await _supabase
            .from('stock_levels')
            .select('quantity')
            .eq('product_id', productId)
            .eq('location_id', locId)
            .maybeSingle();
        if (data != null) {
          total += (data['quantity'] as num?)?.toInt() ?? 0;
          _currentLocationId ??= locId;
        }
      }

      debugPrint('POS _getStock($productId): total=$total across ${locs.length} locations');
      return total;
    } catch (e) {
      debugPrint('_getStock error: $e');
      return 0;
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final data = await _supabase
          .from('products')
          .select()
          .or('name.ilike.%$query%,generated_sku.ilike.%$query%,factory_barcode.ilike.%$query%')
          .limit(10);

      final results = <Map<String, dynamic>>[];
      for (final p in data) {
        final stock = await _getStock(p['id'] as String);
        results.add({...p, '_stock': stock});
      }
      if (mounted) setState(() { _searchResults = results; _isSearching = false; });
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// Opens a purchase sheet for the selected product.
  void _openPurchaseSheet(Map<String, dynamic> product) {
    final stock = (product['_stock'] as int?) ?? 0;
    final price = (product['sale_price'] as num?)?.toDouble() ?? 0;
    final name = product['name'] as String? ?? '';

    // Block out-of-stock
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا المنتج غير متوفر حالياً'), backgroundColor: Colors.red),
      );
      return;
    }

    final qtyNotifier = ValueNotifier<int>(1);
    final customerCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product header
                      AnimatedGlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.05)]),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.shopping_bag_rounded, color: AppColors.primary, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('$price د', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (stock > 0 ? AppColors.success : AppColors.error).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'متوفر: $stock',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: stock > 0 ? AppColors.success : AppColors.error),
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

                      const SizedBox(height: 24),

                      // Quantity selector
                      const Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<int>(
                        valueListenable: qtyNotifier,
                        builder: (_, qty, __) {
                          return AnimatedGlassCard(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _circleBtn(Icons.remove, () {
                                  if (qtyNotifier.value > 1) qtyNotifier.value--;
                                }),
                                const SizedBox(width: 30),
                                Text('$qty', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 30),
                                _circleBtn(Icons.add, () {
                                  if (qtyNotifier.value < stock) {
                                    qtyNotifier.value++;
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('الحد الأقصى المتوفر: $stock'), backgroundColor: Colors.orange),
                                    );
                                  }
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('الحد الأقصى: $stock', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ),

                      const SizedBox(height: 24),

                      // Customer name
                      const Text('اسم المشتري', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: customerCtrl,
                        decoration: InputDecoration(
                          hintText: 'ادخل اسم العميل (اختياري)',
                          prefixIcon: const Icon(Icons.person_rounded),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Seller (auto-filled)
                      const Text('البائع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      AnimatedGlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_rounded, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Text(_sellerName ?? 'غير محدد', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Notes
                      const Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'ملاحظات إضافية (اختياري)',
                          prefixIcon: const Icon(Icons.notes_rounded),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Total & Submit
                      ValueListenableBuilder<int>(
                        valueListenable: qtyNotifier,
                        builder: (_, qty, __) {
                          final total = price * qty;
                          return Column(
                            children: [
                              AnimatedGlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('المجموع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text('${total.toStringAsFixed(0)} د',
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: () => _completeSale(
                                    ctx,
                                    product: product,
                                    qty: qty,
                                    total: total,
                                    customerName: customerCtrl.text.trim(),
                                    notes: notesCtrl.text.trim(),
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded, size: 24),
                                  label: const Text('إتمام البيع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
      ),
    );
  }

  /// Complete the sale: insert transaction, deduct stock, show invoice.
  Future<void> _completeSale(
    BuildContext sheetContext, {
    required Map<String, dynamic> product,
    required int qty,
    required double total,
    required String customerName,
    required String notes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('غير مسجل الدخول');

      // Re-verify stock before committing
      final currentStock = await _getStock(product['id'] as String);
      if (qty > currentStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('الكمية المتوفرة الآن: $currentStock فقط'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Find location for transaction
      String? locationId = _currentLocationId;
      if (locationId == null && _companyId != null) {
        final locs = await _supabase.from('locations').select('id').eq('company_id', _companyId!).limit(1);
        if (locs.isNotEmpty) locationId = locs.first['id'] as String;
      }

      // Insert transaction
      final insertData = <String, dynamic>{
        'company_id': _companyId,
        'location_id': locationId,
        'performed_by': user.id,
        'type': 'sale',
        'total_amount': total,
      };
      // Try to set customer_name (column may or may not exist)
      if (customerName.isNotEmpty) {
        insertData['customer_name'] = customerName;
      }

      final transRes = await _supabase.from('transactions').insert(insertData).select('id').single();
      final transId = transRes['id'];

      // Insert transaction items
      await _supabase.from('transaction_items').insert({
        'transaction_id': transId,
        'product_id': product['id'],
        'quantity': qty,
        'unit_price': (product['sale_price'] as num).toDouble(),
      });

      // Deduct stock - always deduct
      int remaining = qty;
      final stockRecords = await _supabase
          .from('stock_levels')
          .select('quantity, location_id')
          .eq('product_id', product['id'])
          .order('quantity', ascending: false);

      for (final record in stockRecords) {
        if (remaining <= 0) break;
        final recQty = (record['quantity'] as num?)?.toInt() ?? 0;
        if (recQty <= 0) continue;
        final locId = record['location_id'];
        final deduct = remaining > recQty ? recQty : remaining;
        await _supabase.from('stock_levels')
             .update({'quantity': recQty - deduct})
             .eq('product_id', product['id'])
             .eq('location_id', locId);
        debugPrint('POS: Deducted $deduct from stock at $locId. $recQty → ${recQty - deduct}');
        remaining -= deduct;
      }

      // Close the purchase sheet
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();

      // Clear search
      setState(() { _searchCtrl.clear(); _searchResults = []; });

      // Build invoice data
      final now = DateTime.now();
      // Using intl to avoid RTL BiDi mangling of dates and times
      final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(now);

      // Navigate to invoice view
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InvoiceView(invoiceData: {
            'companyName': _companyName ?? 'الشركة',
            'storeName': _currentLocationName ?? '-',
            'sellerName': _sellerName ?? '-',
            'customerName': customerName.isNotEmpty ? customerName : '-',
            'productName': product['name'] ?? '-',
            'quantity': qty,
            'unitPrice': (product['sale_price'] as num).toDouble(),
            'totalAmount': total,
            'dateTime': dateStr,
            'notes': notes,
          }),
        ));
      }
    } catch (e) {
      debugPrint('Sale error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إتمام البيع: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.05)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('نقطة البيع', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.success, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _searchProducts,
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج بالاسم أو الباركود...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchResults = []);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        color: AppColors.primary,
                        onPressed: () async {
                          final code = await context.push<String>('/scanner?returnMode=true');
                          if (code != null && code.isNotEmpty) {
                            _searchCtrl.text = code;
                            _searchProducts(code);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, size: 80, color: Colors.grey.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                _searchCtrl.text.isEmpty ? 'ابحث عن منتج للبدء' : 'لا توجد نتائج',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _searchResults.length,
                          itemBuilder: (ctx, i) {
                            final p = _searchResults[i];
                            final stock = (p['_stock'] as int?) ?? 0;
                            final outOfStock = stock <= 0;
                            final price = (p['sale_price'] as num?)?.toDouble() ?? 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AnimatedGlassCard(
                                onTap: () => _openPurchaseSheet(p),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: (outOfStock ? Colors.grey : AppColors.primary).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        outOfStock ? Icons.block_rounded : Icons.shopping_bag_rounded,
                                        color: outOfStock ? Colors.grey : AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text('$price د', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: (outOfStock ? AppColors.error : AppColors.success).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  outOfStock ? 'نفذ' : 'متوفر: $stock',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                                      color: outOfStock ? AppColors.error : AppColors.success),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_back_ios_rounded, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
