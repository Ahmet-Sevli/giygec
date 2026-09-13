import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';

class CartNotifier extends StateNotifier<List<Product>> {
  CartNotifier() : super([]);

  void addProduct(Product product) {
    // Avoid duplicates
    if (!state.any((p) => p.uid == product.uid)) {
      state = [...state, product];
    }
  }

  void removeProduct(String uid) {
    state = state.where((p) => p.uid != uid).toList();
  }

  void clear() {
    state = [];
  }

  double get totalAmount => state.fold(0, (sum, p) => sum + p.price);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<Product>>(
  (ref) => CartNotifier(),
);

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, p) => sum + p.price);
});
