import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository that queries Supabase for data the AI Assistant needs.
/// All queries are scoped to the user's [companyId] for security.
class AiDataRepository {
  final SupabaseClient _supabase;
  final String companyId;

  AiDataRepository(this._supabase, this.companyId);

  // ─── Sales ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getTotalSales({
    String? startDate,
    String? endDate,
  }) async {
    var query = _supabase
        .from('transactions')
        .select('total_amount, created_at')
        .eq('company_id', companyId)
        .eq('type', 'sale');

    if (startDate != null) query = query.gte('created_at', startDate);
    if (endDate != null) query = query.lte('created_at', endDate);

    final data = await query;
    double total = 0;
    int count = 0;
    for (final row in data) {
      total += (row['total_amount'] as num?)?.toDouble() ?? 0;
      count++;
    }
    return {'total_sales': total, 'orders_count': count};
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 5}) async {
    final data = await _supabase
        .from('transaction_items')
        .select('product_id, quantity, products!inner(name, company_id)')
        .eq('products.company_id', companyId)
        .order('quantity', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Inventory ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLowStockProducts({int limit = 10}) async {
    final data = await _supabase
        .from('stock_levels')
        .select('quantity, min_threshold, product_id, products!inner(name, company_id), location_id, locations!inner(name, company_id)')
        .eq('products.company_id', companyId)
        .order('quantity', ascending: true)
        .limit(limit);

    // Filter to items where quantity <= min_threshold
    final lowStock = (data as List).where((r) {
      final q = (r['quantity'] as num?)?.toInt() ?? 0;
      final t = (r['min_threshold'] as num?)?.toInt() ?? 5;
      return q <= t;
    }).toList();
    return List<Map<String, dynamic>>.from(lowStock);
  }

  Future<Map<String, dynamic>> getProductInfo(String question) async {
    // Check for generic terms
    bool isGeneral = question.contains('كل') || question.contains('جميع') || question.contains('اعرض');
    
    final stopWords = ['ما', 'هي', 'تفاصيل', 'منتج', 'المنتجات', 'المنتج', 'عن', 'كم', 'كمية', 'سعر', 'هل', 'يوجد', 'اعرضلي', 'اعرض', 'كل', 'جميع', 'الي', 'بالمخازن', 'بالمخزن'];
    final words = question.split(' ').where((w) => !stopWords.contains(w) && w.length > 2).toList();
    
    var query = _supabase
        .from('products')
        .select('id, name, description, purchase_price, sale_price, is_active, category_id, categories(name)')
        .eq('company_id', companyId);

    if (words.isNotEmpty && !isGeneral) {
      // Try to match the first significant word
      query = query.ilike('name', '%${words.first}%');
    }

    var data = await query.limit(20); 

    // Fallback if no specific product matched but we have content
    if ((data as List).isEmpty && words.isNotEmpty) {
      data = await _supabase
          .from('products')
          .select('id, name, description, purchase_price, sale_price, is_active, category_id, categories(name)')
          .eq('company_id', companyId)
          .limit(20);
    }

    if ((data as List).isEmpty) {
      return {'found': false, 'message': 'لم يتم العثور على أي منتجات مسجلة في قاعدة البيانات.'};
    }

    // Get stock levels for each found product
    final results = <Map<String, dynamic>>[];
    for (final product in data) {
      final stockData = await _supabase
          .from('stock_levels')
          .select('quantity, location_id, locations!inner(name)')
          .eq('product_id', product['id']);

      int totalStock = 0;
      final locations = <Map<String, dynamic>>[];
      for (final sl in stockData) {
        final q = (sl['quantity'] as num?)?.toInt() ?? 0;
        totalStock += q;
        locations.add({
          'location_name': sl['locations']?['name'] ?? 'غير معروف',
          'quantity': q,
        });
      }
      results.add({
        'name': product['name'],
        'description': product['description'] ?? '',
        'purchase_price': product['purchase_price'],
        'sale_price': product['sale_price'],
        'category': product['categories']?['name'] ?? 'بدون تصنيف',
        'is_active': product['is_active'],
        'total_stock': totalStock,
        'stock_by_location': locations,
      });
    }
    return {'found': true, 'products': results};
  }

  Future<Map<String, dynamic>> getInventorySummary() async {
    // Total products
    final productsData = await _supabase
        .from('products')
        .select('id')
        .eq('company_id', companyId);
    final totalProducts = (productsData as List).length;

    // Total locations
    final locationsData = await _supabase
        .from('locations')
        .select('id, name, type')
        .eq('company_id', companyId);
    final totalLocations = (locationsData as List).length;

    // Low stock count
    final stockData = await _supabase
        .from('stock_levels')
        .select('quantity, min_threshold, locations!inner(company_id)')
        .eq('locations.company_id', companyId);
    int lowStockCount = 0;
    for (final r in stockData) {
      final q = (r['quantity'] as num?)?.toInt() ?? 0;
      final t = (r['min_threshold'] as num?)?.toInt() ?? 5;
      if (q <= t) lowStockCount++;
    }

    return {
      'total_products': totalProducts,
      'total_locations': totalLocations,
      'low_stock_items': lowStockCount,
    };
  }

  // ─── Orders & Transactions ──────────────────────────────

  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 10}) async {
    final data = await _supabase
        .from('transactions')
        .select('id, type, total_amount, notes, created_at, locations!inner(name)')
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Employees ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEmployees() async {
    final data = await _supabase
        .from('profiles')
        .select('id, full_name, role, phone_number')
        .eq('company_id', companyId);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Locations / Stores ─────────────────────────────────

  Future<List<Map<String, dynamic>>> getLocations() async {
    final data = await _supabase
        .from('locations')
        .select('id, name, type, address')
        .eq('company_id', companyId);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Categories ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    final data = await _supabase
        .from('categories')
        .select('id, name')
        .eq('company_id', companyId);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Suppliers ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final data = await _supabase
        .from('external_entities')
        .select('id, name, contact_info, type')
        .eq('company_id', companyId)
        .eq('type', 'supplier');
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Tasks ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getTasksSummary() async {
    final data = await _supabase
        .from('tasks')
        .select('id, title, status, due_date, assigned_to')
        .eq('company_id', companyId);

    int pending = 0, inProgress = 0, completed = 0;
    for (final task in data) {
      switch (task['status']) {
        case 'pending': pending++; break;
        case 'in_progress': inProgress++; break;
        case 'completed': completed++; break;
      }
    }
    return {
      'total_tasks': (data as List).length,
      'pending': pending,
      'in_progress': inProgress,
      'completed': completed,
      'tasks': data.take(10).toList(),
    };
  }
}
