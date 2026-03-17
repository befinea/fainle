import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/barcode_repository.dart';
import '../../auth/application/auth_service.dart';
import '../../inventory/domain/inventory_item.dart';

final barcodeRepositoryProvider = Provider((ref) {
  final supabase = ref.watch(supabaseProvider);
  return BarcodeRepository(supabase);
});

// Provides state for the last scanned item
class BarcodeState {
  final bool isScanning;
  final InventoryItem? scannedItem;
  final String? error;

  BarcodeState({
    this.isScanning = false,
    this.scannedItem,
    this.error,
  });

  BarcodeState copyWith({
    bool? isScanning,
    InventoryItem? scannedItem,
    String? error,
  }) {
    return BarcodeState(
      isScanning: isScanning ?? this.isScanning,
      scannedItem: scannedItem ?? this.scannedItem,
      error: error ?? this.error,
    );
  }
}

class BarcodeNotifier extends StateNotifier<BarcodeState> {
  final BarcodeRepository _repository;

  BarcodeNotifier(this._repository) : super(BarcodeState());

  Future<void> processScan(String sku) async {
    try {
      state = state.copyWith(isScanning: true, error: null);
      final item = await _repository.scanAndLookup(sku);
      if (item != null) {
        state = state.copyWith(isScanning: false, scannedItem: item);
      } else {
        state = state.copyWith(isScanning: false, error: 'Product not found');
      }
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }

  void reset() {
    state = BarcodeState();
  }
}

final barcodeProvider = StateNotifierProvider<BarcodeNotifier, BarcodeState>((ref) {
  final repository = ref.watch(barcodeRepositoryProvider);
  return BarcodeNotifier(repository);
});
