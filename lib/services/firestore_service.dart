import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/product.dart';
import '../models/receipt.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ── Products ──

  /// Fetch a product by its UID (NFC serial) that hasn't been paid yet
  Future<Product?> getUnpaidProductByUid(String uid) async {
    try {
      final doc = await _db
          .collection(AppConstants.productsCollection)
          .doc(uid)
          .get();

      if (!doc.exists) throw Exception('Sistemde bu UID kayıtlı değil: $uid');

      final data = doc.data() as Map<String, dynamic>;
      if (data['isPaid'] == true) throw Exception('Bu ürün zaten satılmış (isPaid=true).');

      final barkod = data['barkod']?.toString().trim();
      if (barkod == null || barkod.isEmpty || barkod == '0000000000000') {
        throw Exception('Bu NFC henüz bir barkoda eşleştirilmemiş.');
      }

      final barkodDoc = await _db.collection('barcodes').doc(barkod).get();
      if (!barkodDoc.exists) throw Exception('Barkod sistemde bulunamadı: $barkod');

      final barkodData = barkodDoc.data() as Map<String, dynamic>;
      final amzId = barkodData['amz_id']?.toString().trim();
      final category = barkodData['category']?.toString().trim();
      final size = barkodData['size']?.toString() ?? '';

      if (amzId == null || amzId.isEmpty) throw Exception('Barkoda ait amz_id bulunamadı.');

      Map<String, dynamic>? urunData;
      String matchedCategory = category ?? '';

      // 1. Kendi kategorisinde ara (Document ID ile)
      if (category != null && category.isNotEmpty) {
        final urunDoc = await _db
            .collection('catalog')
            .doc(category)
            .collection('products')
            .doc(amzId)
            .get();

        if (urunDoc.exists) {
          urunData = urunDoc.data();
        }
      }

      // 2. Fallback: Diğer kategorilerde ara
      if (urunData == null) {
        final fallbackCats = ['ayakkabi', 'tisort', 'pantolon', 'elbise'];
        for (final cat in fallbackCats) {
          final urunDoc = await _db
              .collection('catalog')
              .doc(cat)
              .collection('products')
              .doc(amzId)
              .get();
          if (urunDoc.exists) {
            urunData = urunDoc.data();
            matchedCategory = cat;
            break;
          }
        }
      }

      if (urunData == null) {
        throw Exception('Katalogda bu ürüne ait detay bulunamadı: amz_id=$amzId');
      }

      return Product(
        uid: uid,
        name: urunData['name'] ?? urunData['title'] ?? '',
        price: double.tryParse((urunData['price'] ?? urunData['fiyat'] ?? '0').toString()) ?? 0.0,
        size: size,
        priceText: urunData['priceText']?.toString() ?? '',
        imageUrl: urunData['imageUrl'] ?? urunData['image'] ?? '',
        description: urunData['description']?.toString() ?? '',
        category: matchedCategory,
        styleTags: List<String>.from(urunData['styleTags'] ?? []),
        isPaid: false,
        barcode: barkod,
        color: urunData['color']?.toString() ?? urunData['renk']?.toString() ?? '',
      );
    } catch (e) {
      if (e is Exception) rethrow; // Özel fırlattığımız hataları yukarı gönder
      throw Exception('Sistem hatası: $e');
    }
  }

  /// Search products by category & styleTags for AI recommendations
  Future<List<Product>> searchProducts({
    String? category,
    List<String>? styleTags,
    int limit = 10,
  }) async {
    try {
      Query query = _db
          .collection(AppConstants.productsCollection)
          .where('isPaid', isEqualTo: false);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query.limit(limit).get();
      List<Product> products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();

      // Filter by styleTags locally if provided
      if (styleTags != null && styleTags.isNotEmpty) {
        products = products.where((product) {
          return product.styleTags.any(
            (tag) => styleTags.any(
              (sTag) => tag.toLowerCase().contains(sTag.toLowerCase()),
            ),
          );
        }).toList();
      }

      return products;
    } catch (e) {
      rethrow;
    }
  }

  // ── Receipts ──

  /// Create a receipt and mark products as paid
  Future<Receipt> createReceiptAndPay({
    required String userId,
    required List<Product> cartItems,
  }) async {
    final receiptId = _uuid.v4();
    final totalAmount = cartItems.fold<double>(
      0,
      (sum, item) => sum + item.price,
    );

    final receipt = Receipt(
      receiptId: receiptId,
      userId: userId,
      timestamp: DateTime.now(),
      totalAmount: totalAmount,
      items: cartItems
          .map((p) => ReceiptItem(
                uid: p.uid,
                name: p.name,
                price: p.price,
                barcode: p.barcode,
                size: p.size,
                color: p.color,
              ))
          .toList(),
    );

    // Use a batch to write receipt and update all products atomically
    final batch = _db.batch();

    // Create receipt document
    batch.set(
      _db.collection(AppConstants.receiptsCollection).doc(receiptId),
      receipt.toFirestore(),
    );

    // Mark each product as paid
    for (final item in cartItems) {
      batch.update(
        _db.collection(AppConstants.productsCollection).doc(item.uid),
        {'isPaid': true},
      );
    }

    await batch.commit();

    // Stok güncelle — her ürün için barkod stoku azalt (Render sunucusu üzerinden)
    for (final item in cartItems) {
      try {
        await http.post(
          Uri.parse('${AppConstants.renderBaseUrl}/depo/satin-al'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'uid': item.uid}),
        );
      } catch (e) {
        // Stok güncellemesi arka planda — başarısız olsa da satış tamamlanmış sayılır
        print('Stok güncelleme hatası (${item.uid}): \$e');
      }
    }

    return receipt;
  }

  /// Get receipts for a specific user
  Stream<List<Receipt>> getUserReceipts(String userId) {
    return _db
        .collection(AppConstants.receiptsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final receipts =
          snapshot.docs.map((doc) => Receipt.fromFirestore(doc)).toList();
      // Sort locally instead of Firestore orderBy (avoids composite index)
      receipts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return receipts;
    });
  }
}
