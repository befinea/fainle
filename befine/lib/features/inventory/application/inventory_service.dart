import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/inventory_item.dart';
import '../data/inventory_repository.dart';
import '../../auth/application/auth_service.dart';

final inventoryRepositoryProvider = Provider((ref) {
  final supabase = ref.watch(supabaseProvider);
  return InventoryRepository(supabase);
});

// Stream provider for real-time updates
final inventoryStreamProvider = StreamProvider<List<InventoryItem>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.streamItems();
});

class InventoryState {
  final bool isLoading;
  final String? error;

  InventoryState({this.isLoading = false, this.error});

  InventoryState copyWith({bool? isLoading, String? error}) {
    return InventoryState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Can be null intentionally
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryRepository _repository;

  InventoryNotifier(this._repository) : super(InventoryState());

  Future<void> addItem(InventoryItem item) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.createItem(item);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateItem(InventoryItem item) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.updateItem(item);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.deleteItem(id);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> adjustStock(String id, int quantityChange) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.adjustStock(id, quantityChange);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final inventoryNotifierProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return InventoryNotifier(repository);
});
