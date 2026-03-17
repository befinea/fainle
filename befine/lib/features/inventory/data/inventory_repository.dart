import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/inventory_item.dart';
import '../../../../core/error/exceptions.dart';

class InventoryRepository {
  final SupabaseClient _supabase;

  InventoryRepository(this._supabase);

  // Get all items
  Future<List<InventoryItem>> getItems() async {
    try {
      final response = await _supabase.from('inventory').select().order('name');
      return (response as List).map((e) => InventoryItem.fromJson(e)).toList();
    } catch (e) {
      throw ServerException('Failed to fetch inventory items: $e');
    }
  }

  // Real-time stream of all inventory items
  Stream<List<InventoryItem>> streamItems() {
    return _supabase.from('inventory').stream(primaryKey: ['id']).map(
      (data) => data.map((e) => InventoryItem.fromJson(e)).toList(),
    );
  }

  // Create a new item
  Future<InventoryItem> createItem(InventoryItem item) async {
    try {
      final response = await _supabase
          .from('inventory')
          .insert(item.toJson()..remove('id')) // DB generates ID
          .select()
          .single();
      return InventoryItem.fromJson(response);
    } catch (e) {
      throw ServerException('Failed to create item: $e');
    }
  }

  // Update an item
  Future<InventoryItem> updateItem(InventoryItem item) async {
    try {
      final response = await _supabase
          .from('inventory')
          .update(item.toJson())
          .eq('id', item.id)
          .select()
          .single();
      return InventoryItem.fromJson(response);
    } catch (e) {
      throw ServerException('Failed to update item: $e');
    }
  }

  // Delete an item
  Future<void> deleteItem(String id) async {
    try {
      await _supabase.from('inventory').delete().eq('id', id);
    } catch (e) {
      throw ServerException('Failed to delete item: $e');
    }
  }

  // Update stock quantity directly (e.g. from POS)
  Future<void> adjustStock(String id, int quantityChange) async {
    try {
      // Use RPC for atomic operations if concurrency is high, or simple update
      final itemRes = await _supabase
          .from('inventory')
          .select('quantity')
          .eq('id', id)
          .single();
      
      final currentQuantity = itemRes['quantity'] as int;
      final newQuantity = currentQuantity + quantityChange;

      await _supabase
          .from('inventory')
          .update({'quantity': newQuantity})
          .eq('id', id);
    } catch (e) {
      throw ServerException('Failed to adjust stock: $e');
    }
  }
}
