import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

  /// Fetch stock for a product across all company locations with a single query.
  /// Returns total stock across all company locations. Returns 0 if not found.
  Future<int> _getStock(String productId) async {
    try {
      if (_companyId == null) return 0;

      // Single query: join stock_levels with locations to filter by company
      final data = await _supabase
          .from('stock_levels')
          .select('quantity, location_id, locations!inner(company_id)')
          .eq('product_id', productId)
          .eq('locations.company_id', _companyId!);

      if (data.isEmpty) return 0;

      int total = 0;
      for (final row in data) {
        total += (row['quantity'] as num?)?.toInt() ?? 0;
        _currentLocationId ??= row['location_id'] as String?;
      }

      debugPrint('POS _getStock($productId): total=$total across ${data.length} locations');
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

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: isDark ? 20 : 5, sigmaY: isDark ? 20 : 5),
            child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceContainerHigh.withOpacity(0.92) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: isDark ? Border.all(color: AppColors.ghostBorder, width: 1) : null,
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
                              const SizedBox(height: 180),
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
        ),
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

      // Find the location that actually has stock for this product.
      // The DB trigger deducts from the transaction's location_id, so it MUST
      // match where the stock exists.
      String? locationId;
      if (_companyId != null) {
        final stockLocs = await _supabase
            .from('stock_levels')
            .select('location_id, quantity, locations!inner(company_id)')
            .eq('product_id', product['id'])
            .eq('locations.company_id', _companyId!)
            .gte('quantity', qty)
            .order('quantity', ascending: false)
            .limit(1);
        if (stockLocs.isNotEmpty) {
          locationId = stockLocs.first['location_id'] as String;
        }
      }
      // Fallback to _currentLocationId if no specific stock location found
      locationId ??= _currentLocationId;

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

      // Stock deduction is handled automatically by the DB trigger
      // 'trg_update_stock_on_transaction' which fires on transaction_items INSERT.
      // No manual deduction needed here.

      // Close the purchase sheet
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();

      // Clear search
      setState(() { _searchCtrl.clear(); _searchResults = []; });

      // Build invoice data
      final now = DateTime.now();
      // Using intl to avoid RTL BiDi mangling of dates and times
      final dateStr = DateFormat('yyyy/MM/dd hh:mm a').format(now);

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : null,
          body: isDesktop ? _buildDesktop(context, isDark) : _buildMobile(context, isDark),
        );
      },
    );
  }

  // ─── Mobile Layout (Stitch Exact match) ───
  Widget _buildMobile(BuildContext context, bool isDark) {
    return Column(
      children: [
        // TopAppBar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 16), // px-6 py-4
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff0f172a).withOpacity(0.4) : Colors.white.withOpacity(0.6), // bg-slate-900/40
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), // rounded-b-2xl
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))), // border-b border-white/10
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.05), blurRadius: 40, offset: const Offset(0, 20)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8), // p-2
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1), // bg-primary/10
                        borderRadius: BorderRadius.circular(12), // rounded-xl
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20)], // shadow-[0_0_20px_rgba(133,173,255,0.3)]
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12), // gap-3
                    Text('نقطة البيع', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
                  borderRadius: BorderRadius.circular(12), // rounded-xl
                  child: Container(
                    width: 40, height: 40, // w-10 h-10
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1), // bg-secondary/10
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 180), // px-5 py-6 pb-48
              children: [
                // Search Bar
                AnimatedGlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  borderRadius: 16, // rounded-2xl
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _searchProducts,
                    style: GoogleFonts.inter(),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منتج بالاسم أو الباركود...',
                      hintStyle: GoogleFonts.inter(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchResults = []);
                              },
                            ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 1, height: 24,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                              color: AppColors.primary,
                              onPressed: () async {
                                final code = await context.push<String>('/scanner?returnMode=true');
                                if (code != null && code.isNotEmpty) {
                                  _searchCtrl.text = code;
                                  _searchProducts(code);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 32), // space-y-8

                // Product List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('النتائج المعروضة', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('${_searchResults.length} منتجات عرضت', style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                  ],
                ),
                const SizedBox(height: 16), // space-y-4

                if (_isSearching)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                else if (_searchResults.isEmpty)
                   Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _searchCtrl.text.isEmpty ? 'ابحث للبدء في البيع' : 'لا توجد نتائج',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                else
                  ..._searchResults.map((p) => _buildMobileProductCard(p, isDark)).toList(),
              ],
            ),
          ),
        ],
      );
  }

  Widget _buildMobileProductCard(Map<String, dynamic> p, bool isDark) {
    final stock = (p['_stock'] as int?) ?? 0;
    final outOfStock = stock <= 0;
    final price = (p['sale_price'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16), // space-y-4
      child: AnimatedGlassCard(
        onTap: outOfStock ? null : () => _openPurchaseSheet(p),
        padding: const EdgeInsets.all(16), // p-4
        borderRadius: 24, // rounded-3xl
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 56, height: 56, // w-14 h-14
                  decoration: BoxDecoration(
                    color: (outOfStock ? Colors.grey : AppColors.primary).withOpacity(0.1), // bg-surface-variant
                    borderRadius: BorderRadius.circular(16), // rounded-2xl
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)], // shadow-inner
                  ),
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    color: outOfStock ? Colors.grey : AppColors.primary,
                    size: 32, // text-3xl
                  ),
                ),
                const SizedBox(width: 16), // gap-4
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'] ?? '',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16, color: outOfStock ? Colors.grey : null),
                    ),
                    const SizedBox(height: 4), // space-y-1
                    Row(
                      children: [
                        Text('$price د', style: GoogleFonts.manrope(color: outOfStock ? Colors.grey : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(width: 12), // gap-3
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
                          decoration: BoxDecoration(
                            color: (outOfStock ? AppColors.error : AppColors.success).withOpacity(0.2), // bg-secondary-container/30
                            borderRadius: BorderRadius.circular(999), // rounded-full
                          ),
                          child: Text(
                            outOfStock ? 'نفذ' : 'متوفر: $stock',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: outOfStock ? AppColors.error : AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Icon(Icons.chevron_left_rounded, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }

  // ─── Desktop Layout (Stitch Exact match) ───
  Widget _buildDesktop(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32).copyWith(top: 48), // p-8 lg:p-12 mt-12
      child: Column(
        children: [
          // TopNavBar Structure
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // User Info Right (flex-row-reverse rtl)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerHigh : Colors.grey.shade200, // bg-surface-variant
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_circle_rounded, size: 24),
                  ),
                  const SizedBox(width: 16), // gap-4
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_sellerName ?? 'المستخدم', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('نقطة البيع - المتجر الدائم', style: GoogleFonts.manrope(fontSize: 10, letterSpacing: 1.5, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)), // text-[10px] uppercase tracking-widest
                    ],
                  ),
                ],
              ),
              // Title & Button Left
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedGlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // px-6 py-2.5
                      borderRadius: 999, // rounded-full
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: AppColors.success), // text-secondary
                          const SizedBox(width: 8), // gap-2
                          Text('سجل المبيعات', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24), // gap-6
                  Text('نقطة البيع', style: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)), // text-4xl font-extrabold tracking-tight
                ],
              ),
            ],
          ),

          const SizedBox(height: 64), // mb-16 (4rem -> 64px)

          // Search Section
          SizedBox(
            width: 1024, // max-w-5xl
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05), // bg-primary/5
                      borderRadius: BorderRadius.circular(999), // rounded-full
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 40)], // blur-3xl opacity-50
                    ),
                  ),
                ),
                AnimatedGlassCard(
                  padding: const EdgeInsets.all(8), // p-2
                  borderRadius: 16, // rounded-2xl
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 24, left: 16), // pr-6
                        child: Icon(Icons.search_rounded, size: 24, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight), // text-2xl
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _searchProducts,
                          style: GoogleFonts.inter(fontSize: 20), // text-xl
                          decoration: InputDecoration(
                            hintText: 'ابحث عن منتج بالاسم أو الباركود...',
                            hintStyle: GoogleFonts.inter(color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight).withOpacity(0.5)), // placeholder:text-on-surface-variant/50
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 24), // py-4
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 24),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchResults = []);
                          },
                        ),
                      InkWell(
                        onTap: () async {
                           final code = await context.push<String>('/scanner?returnMode=true');
                           if (code != null && code.isNotEmpty) {
                             _searchCtrl.text = code;
                             _searchProducts(code);
                           }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // px-6 py-4
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12), // rounded-xl
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded, color: Colors.white), // text-on-primary-container
                              const SizedBox(width: 8), // gap-2
                              Text('ماسح الرمز', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 64),

          // Results Table
          Expanded(
            child: SizedBox(
              width: 1152, // max-w-6xl
              child: AnimatedGlassCard(
                padding: EdgeInsets.zero,
                borderRadius: 24, // rounded-3xl
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24), // px-8 py-6
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05), // bg-white/5
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))), // border-b border-white/5
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text('المنتج', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight))), // text-sm
                          Expanded(flex: 2, child: Text('سعر البيع', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight))),
                          Expanded(flex: 2, child: Text('حالة المخزون', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight))),
                          Expanded(flex: 2, child: Text('إجراء', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight))),
                        ],
                      ),
                    ),
                    
                    // Table Body
                    Expanded(
                      child: _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                         ? Center(child: Text(_searchCtrl.text.isEmpty ? 'ابحث عن منتج للبدء' : 'لا توجد نتائج', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18)))
                         : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final p = _searchResults[index];
                                final stock = (p['_stock'] as int?) ?? 0;
                                final outOfStock = stock <= 0;
                                final price = (p['sale_price'] as num?)?.toDouble() ?? 0;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24), // px-8 py-6
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))), // divide-y divide-white/5
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48, height: 48, // w-12 h-12
                                              decoration: BoxDecoration(
                                                color: isDark ? AppColors.surfaceContainerHigh : Colors.grey.shade200, // bg-surface-container-highest
                                                borderRadius: BorderRadius.circular(16), // rounded-2xl
                                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)], // shadow-inner
                                              ),
                                              child: Icon(Icons.shopping_bag_rounded, color: outOfStock ? Colors.grey : AppColors.primary),
                                            ),
                                            const SizedBox(width: 16), // gap-4
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(p['name'] ?? '', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18, color: outOfStock ? Colors.grey : null)), // text-lg
                                                Text('منتج متاح', style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)), // text-xs
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Text('$price', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5, color: outOfStock ? Colors.grey : null)), // text-xl tracking-tight
                                            const SizedBox(width: 4), // mr-1
                                            Text('د.ع', style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)), // text-xs
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
                                              decoration: BoxDecoration(
                                                color: (outOfStock ? AppColors.error : AppColors.success).withOpacity(0.2), // bg-secondary-container/20
                                                borderRadius: BorderRadius.circular(999), // rounded-full
                                                border: Border.all(color: (outOfStock ? AppColors.error : AppColors.success).withOpacity(0.2)), // border
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6, height: 6, // w-1.5 h-1.5
                                                    decoration: BoxDecoration(
                                                      color: outOfStock ? AppColors.error : AppColors.success,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6), // gap-1.5
                                                  Text(outOfStock ? 'نفذ المخزون' : 'متوفر: $stock', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12, color: outOfStock ? AppColors.error : AppColors.success)), // text-xs font-bold
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft, // text-left
                                          child: InkWell(
                                            onTap: outOfStock ? null : () => _openPurchaseSheet(p),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10), // px-8 py-2.5
                                              decoration: BoxDecoration(
                                                color: outOfStock ? (isDark ? AppColors.surfaceContainerHigh : Colors.grey.shade300) : AppColors.primary.withOpacity(0.1), // glass-panel or bg-surface-variant
                                                borderRadius: BorderRadius.circular(12), // rounded-xl
                                                border: Border.all(color: outOfStock ? Colors.transparent : AppColors.primary.withOpacity(0.2)), // border-primary/20
                                              ),
                                              child: Text('بيع الآن', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: outOfStock ? Colors.grey : AppColors.primary)), // font-bold
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                           ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

