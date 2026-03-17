import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../inventory/domain/inventory_item.dart';

class BarcodeRepository {
  final SupabaseClient _supabase;

  BarcodeRepository(this._supabase);

  Future<InventoryItem?> scanAndLookup(String sku) async {
    try {
      final response = await _supabase
          .from('inventory')
          .select()
          .eq('sku', sku)
          .maybeSingle();

      if (response == null) return null;

      return InventoryItem.fromJson(response);
    } catch (e) {
      throw ServerException('Failed to look up barcode: $e');
    }
  }

  Future<bool> isSkuUnique(String sku) async {
    try {
      final response = await _supabase
          .from('inventory')
          .select('id')
          .eq('sku', sku)
          .maybeSingle();

      return response == null; // True if no item with this SKU exists
    } catch (e) {
      throw ServerException('Failed to check SKU uniqueness: $e');
    }
  }
}
