import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import 'auth_provider.dart';

class SavedOutfit {
  final String id;
  final DateTime date;
  final List<Product> products;
  final String promptKey;

  SavedOutfit({
    required this.id,
    required this.date,
    required this.products,
    this.promptKey = '',
  });

  factory SavedOutfit.fromFirestore(Map<String, dynamic> json) => SavedOutfit(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        products: (json['products'] as List<dynamic>)
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList(),
        promptKey: json['promptKey'] as String? ?? '',
      );
}

class OutfitNotifier extends StateNotifier<List<SavedOutfit>> {
  final String? userId;

  OutfitNotifier(this.userId) : super([]) {
    if (userId != null) {
      _loadFromFirebase();
    }
  }

  Future<void> _loadFromFirebase() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('saved_outfits')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      final loadedOutfits = snap.docs
          .map((doc) => SavedOutfit.fromFirestore(doc.data()))
          .toList();

      state = loadedOutfits;
    } catch (e) {
      // Firebase hatası — state boş kalır
    }
  }

  /// Duplicate kontrolü yaparak kaydet.
  Future<bool> saveOutfit(List<Product> products) async {
    if (products.isEmpty || userId == null) return false;

    final productIds = products.map((p) => p.uid).toList()..sort();
    final promptKey = productIds.join('|');

    final isDuplicate = state.any((o) => o.promptKey == promptKey);
    if (isDuplicate) return false;

    final newOutfit = SavedOutfit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      products: List.from(products),
      promptKey: promptKey,
    );

    state = [newOutfit, ...state];
    await _saveToFirebase(newOutfit);
    return true;
  }

  /// Kombinasyon sil
  Future<void> deleteOutfit(String outfitId) async {
    state = state.where((o) => o.id != outfitId).toList();
    await _deleteFromFirebase(outfitId);
  }

  Future<void> _saveToFirebase(SavedOutfit outfit) async {
    if (userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('saved_outfits')
          .doc(outfit.id)
          .set({
        'id': outfit.id,
        'userId': userId,
        'date': outfit.date.toIso8601String(),
        'products': outfit.products.map((p) => p.toJson()).toList(),
        'promptKey': outfit.promptKey,
      });
    } catch (_) {}
  }

  Future<void> _deleteFromFirebase(String outfitId) async {
    try {
      await FirebaseFirestore.instance
          .collection('saved_outfits')
          .doc(outfitId)
          .delete();
    } catch (_) {}
  }
}

final outfitProvider =
    StateNotifierProvider<OutfitNotifier, List<SavedOutfit>>((ref) {
  final user = ref.watch(currentUserProvider);
  return OutfitNotifier(user?.uid);
});
