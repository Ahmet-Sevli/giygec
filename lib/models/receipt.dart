import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptItem {
  final String uid;
  final String name;
  final double price;
  final String barcode;
  final String size;
  final String color;

  const ReceiptItem({
    required this.uid,
    required this.name,
    required this.price,
    this.barcode = '',
    this.size = '',
    this.color = '',
  });

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      barcode: map['barcode'] ?? '',
      size: map['size'] ?? '',
      color: map['color'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'price': price,
      'barcode': barcode,
      'size': size,
      'color': color,
    };
  }
}

class Receipt {
  final String receiptId;
  final String userId;
  final DateTime timestamp;
  final double totalAmount;
  final List<ReceiptItem> items;

  const Receipt({
    required this.receiptId,
    required this.userId,
    required this.timestamp,
    required this.totalAmount,
    required this.items,
  });

  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Receipt(
      receiptId: data['receiptId'] ?? doc.id,
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => ReceiptItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'receiptId': receiptId,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
}
