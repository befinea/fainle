import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/error/exceptions.dart';
import '../../ui/widgets/animated_glass_card.dart';
import 'data/operations_repository.dart';

class TransactionCreateScreen extends StatefulWidget {
  final String type; // 'import' | 'export'

  const TransactionCreateScreen({super.key, required this.type});

  @override
  State<TransactionCreateScreen> createState() => _TransactionCreateScreenState();
}

class _TransactionCreateScreenState extends State<TransactionCreateScreen> {
  late final OperationsRepository _repo;

  bool _loadingWarehouses = true;
  bool _loadingStores = false;
  bool _loadingStock = false;
  bool _submitting = false;

  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _stock = [];

  Map<String, dynamic>? _selectedWarehouse;
  Map<String, dynamic>? _selectedStore;
  Map<String, dynamic>? _selectedStockRow;

  final _qtyCtrl = TextEditingController(text: '1');
  int _quantity = 1;
  num _unitPrice = 0;
  num _total = 0;

  @override
  void initState() {
    super.initState();
    _repo = OperationsRepository(Supabase.instance.client);
    _fetchWarehouses();
    _qtyCtrl.addListener(_onQtyChanged);
  }

  @override
  void dispose() {
    _qtyCtrl.removeListener(_onQtyChanged);
    _qtyCtrl.dispose();
    super.dispose();
  }

  bool get _isImport => widget.type == 'import';

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

  Future<void> _fetchWarehouses() async {
    setState(() => _loadingWarehouses = true);
    try {
      final data = await _repo.getWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = data;
        _loadingWarehouses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingWarehouses = false);
      _showError('فشل جلب المخازن: $e');
    }
  }

  Future<void> _onSelectWarehouse(Map<String, dynamic>? wh) async {
    setState(() {
      _selectedWarehouse = wh;
      _selectedStore = null;
      _selectedStockRow = null;
      _stores = [];
      _stock = [];
      _unitPrice = 0;
      _total = 0;
      _loadingStores = wh != null;
      _loadingStock = false;
    });

    if (wh == null) return;

    try {
      final data = await _repo.getStoresForWarehouse(wh['id'] as String);
      if (!mounted) return;
      setState(() {
        _stores = data;
        _loadingStores = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStores = false);
      _showError('فشل جلب المتاجر: $e');
    }
  }

  Future<void> _onSelectStore(Map<String, dynamic>? store) async {
    setState(() {
      _selectedStore = store;
      _selectedStockRow = null;
      _stock = [];
      _unitPrice = 0;
      _total = 0;
      _loadingStock = store != null;
    });

    if (store == null) return;

    try {
      final data = await _repo.getStockForStore(store['id'] as String);
      if (!mounted) return;
      setState(() {
        _stock = data;
        _loadingStock = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStock = false);
      _showError('فشل جلب المنتجات: $e');
    }
  }

  void _onSelectProduct(Map<String, dynamic>? stockRow) {
    setState(() {
      _selectedStockRow = stockRow;
      _unitPrice = _calcUnitPrice(stockRow);
      _total = _unitPrice * _quantity;
    });
  }

  num _calcUnitPrice(Map<String, dynamic>? stockRow) {
    if (stockRow == null) return 0;
    final product = stockRow['products'] as Map<String, dynamic>?;
    if (product == null) return 0;
    final purchase = product['purchase_price'];
    final sale = product['sale_price'];
    final purchaseNum = purchase is num ? purchase : num.tryParse('$purchase') ?? 0;
    final saleNum = sale is num ? sale : num.tryParse('$sale') ?? 0;
    return _isImport ? purchaseNum : saleNum;
  }

  void _onQtyChanged() {
    final parsed = int.tryParse(_qtyCtrl.text.trim());
    final q = (parsed == null || parsed <= 0) ? 1 : parsed;
    if (q == _quantity) return;
    setState(() {
      _quantity = q;
      _total = _unitPrice * _quantity;
    });
  }

  Future<void> _submit() async {
    final wh = _selectedWarehouse;
    final store = _selectedStore;
    final stockRow = _selectedStockRow;

    if (wh == null) {
      _showError('اختر المخزن أولاً');
      return;
    }
    if (store == null) {
      _showError('اختر المتجر أولاً');
      return;
    }
    if (stockRow == null) {
      _showError('اختر المنتج أولاً');
      return;
    }

    final product = stockRow['products'] as Map<String, dynamic>?;
    final productId = product?['id'] as String?;
    if (productId == null) {
      _showError('المنتج غير صالح');
      return;
    }

    setState(() => _submitting = true);
    try {
      final transactionId = await _repo.createTransaction(
        type: widget.type,
        locationId: store['id'] as String,
        externalEntityId: null,
        totalAmount: _total,
        notes: 'warehouse:${wh['id']}',
      );

      await _repo.addTransactionItem(
        transactionId: transactionId,
        productId: productId,
        quantity: _quantity,
        unitPrice: _unitPrice,
      );

      await _repo.updateTransactionTotal(transactionId, _total);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ServerException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isImport ? 'وارد جديد' : 'صادر جديد';
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
          child: Column(
            children: [
              _buildAppBar(context, title),
              Expanded(
                child: _loadingWarehouses
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildStepSection(
                            title: '1) اختيار الموقع والمستودع',
                            child: Column(
                              children: [
                                _buildDropdown(
                                  label: 'المخزن',
                                  value: _selectedWarehouse?['id'] as String?,
                                  items: _warehouses.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] as String? ?? ''))).toList(),
                                  onChanged: (id) => _onSelectWarehouse(_warehouses.where((e) => e['id'] == id).cast<Map<String, dynamic>?>().firstOrNull),
                                ),
                                if (_selectedWarehouse != null) ...[
                                  const SizedBox(height: 16),
                                  _loadingStores
                                      ? const Center(child: CircularProgressIndicator())
                                      : _buildDropdown(
                                          label: 'المتجر المستهدف',
                                          value: _selectedStore?['id'] as String?,
                                          items: _stores.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String? ?? ''))).toList(),
                                          onChanged: (id) => _onSelectStore(_stores.where((e) => e['id'] == id).cast<Map<String, dynamic>?>().firstOrNull),
                                        ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_selectedStore != null)
                            _buildStepSection(
                              title: '2) تفاصيل المنتج',
                              child: Column(
                                children: [
                                  _loadingStock
                                      ? const Center(child: CircularProgressIndicator())
                                      : _buildDropdown(
                                          label: 'اختر المنتج',
                                          value: (_selectedStockRow?['products'] as Map<String, dynamic>?)?['id'] as String?,
                                          items: _stock.map((row) {
                                            final product = row['products'] as Map<String, dynamic>?;
                                            return DropdownMenuItem(value: product?['id'] as String?, child: Text('${product?['name']} (المتوفر: ${row['quantity']})'));
                                          }).toList(),
                                          onChanged: (id) => _onSelectProduct(_stock.where((e) => (e['products'] as Map<String, dynamic>?)?['id'] == id).cast<Map<String, dynamic>?>().firstOrNull),
                                        ),
                                  if (_selectedStockRow != null) ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _qtyCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'الكمية المطلوبة',
                                        prefixIcon: Icon(Icons.add_shopping_cart, color: theme.colorScheme.primary),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.05),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (_selectedStockRow != null)
                            AnimatedGlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الحساب النهائي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                        child: Text('${_quantity} وحدة', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32),
                                  _buildSummaryRow('سعر الوحدة', '${_unitPrice} د'),
                                  const SizedBox(height: 8),
                                  _buildSummaryRow('الإجمالي', '${_total} د', isTotal: true),
                                ],
                              ),
                            ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: _submitting || _selectedStockRow == null ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(_isImport ? Icons.download_rounded : Icons.upload_rounded),
                              label: Text(_submitting ? 'جارٍ المعالجة...' : 'تأكيد وحفظ العملية', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.all(12)),
          ),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStepSection({required String title, required Widget child}) {
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildDropdown({required String label, required String? value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          hint: Text(label, style: const TextStyle(fontSize: 14)),
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(border: InputBorder.none),
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isTotal ? null : Colors.grey, fontWeight: isTotal ? FontWeight.bold : null, fontSize: isTotal ? 16 : 14)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTotal ? 22 : 16, color: isTotal ? AppColors.primary : null)),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

