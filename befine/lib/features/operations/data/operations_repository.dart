import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exceptions.dart';

class OperationsRepository {
  final SupabaseClient _supabase;

  OperationsRepository(this._supabase);

  Future<String> getCurrentCompanyIdOrThrow() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw ServerException('Not authenticated');

    final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
    final companyId = profile['company_id'] as String?;
    if (companyId == null || companyId.isEmpty) throw ServerException('No company_id found for current user');
    return companyId;
  }

  Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      final companyId = await getCurrentCompanyIdOrThrow();
      final data = await _supabase
          .from('locations')
          .select()
          .eq('company_id', companyId)
          .eq('type', 'warehouse')
          .order('created_at');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      throw ServerException('Failed to fetch warehouses: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStoresForWarehouse(String warehouseId) async {
    try {
      final companyId = await getCurrentCompanyIdOrThrow();
      final data = await _supabase
          .from('locations')
          .select()
          .eq('company_id', companyId)
          .eq('type', 'store')
          .eq('parent_id', warehouseId)
          .order('created_at');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      throw ServerException('Failed to fetch stores: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStockForStore(String storeId) async {
    try {
      final data = await _supabase
          .from('stock_levels')
          .select('quantity, products(id, name, purchase_price, sale_price)')
          .eq('location_id', storeId)
          .order('last_updated', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      throw ServerException('Failed to fetch stock levels: $e');
    }
  }

  Future<String> createTransaction({
    required String type,
    required String locationId,
    required String? externalEntityId,
    required num totalAmount,
    String? notes,
  }) async {
    try {
      final companyId = await getCurrentCompanyIdOrThrow();
      final performedBy = _supabase.auth.currentUser?.id;

      final res = await _supabase
          .from('transactions')
          .insert({
            'company_id': companyId,
            'location_id': locationId,
            'performed_by': performedBy,
            'external_entity_id': externalEntityId,
            'type': type,
            'total_amount': totalAmount,
            'notes': notes,
          })
          .select('id')
          .single();

      return res['id'] as String;
    } catch (e) {
      throw ServerException('Failed to create transaction: $e');
    }
  }

  Future<void> addTransactionItem({
    required String transactionId,
    required String productId,
    required int quantity,
    required num unitPrice,
  }) async {
    try {
      await _supabase.from('transaction_items').insert({
        'transaction_id': transactionId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
      });
    } catch (e) {
      throw ServerException('Failed to create transaction item: $e');
    }
  }

  Future<void> updateTransactionTotal(String transactionId, num totalAmount) async {
    try {
      await _supabase.from('transactions').update({'total_amount': totalAmount}).eq('id', transactionId);
    } catch (e) {
      throw ServerException('Failed to update transaction total: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions({required String type, int limit = 50}) async {
    try {
      final companyId = await getCurrentCompanyIdOrThrow();
      final data = await _supabase
          .from('transactions')
          .select('id, type, total_amount, created_at, location_id, locations(name)')
          .eq('company_id', companyId)
          .eq('type', type)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      throw ServerException('Failed to fetch transactions: $e');
    }
  }
}

