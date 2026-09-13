import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String uid;
  final String name;
  final double price;
  final String size;
  final String priceText;
  final String imageUrl;
  final String description;
  final String category;
  final List<String> styleTags;
  final bool isPaid;
  final String barcode;
  final String color;

  const Product({
    required this.uid,
    required this.name,
    required this.price,
    required this.size,
    required this.priceText,
    required this.imageUrl,
    required this.description,
    required this.category,
    required this.styleTags,
    required this.isPaid,
    this.barcode = '',
    this.color = '',
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      uid: doc.id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      size: data['size'] ?? '',
      priceText: data['priceText'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      styleTags: List<String>.from(data['styleTags'] ?? []),
      isPaid: data['isPaid'] ?? false,
      barcode: data['barcode'] ?? data['barkod'] ?? '',
      color: data['color'] ?? data['renk'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'size': size,
      'priceText': priceText,
      'imageUrl': imageUrl,
      'description': description,
      'category': category,
      'styleTags': styleTags,
      'isPaid': isPaid,
      'barcode': barcode,
      'color': color,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      size: json['size'] ?? '',
      priceText: json['priceText'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      styleTags: List<String>.from(json['styleTags'] ?? []),
      isPaid: json['isPaid'] ?? false,
      barcode: json['barcode'] ?? json['barkod'] ?? '',
      color: json['color'] ?? json['renk'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'price': price,
      'size': size,
      'priceText': priceText,
      'imageUrl': imageUrl,
      'description': description,
      'category': category,
      'styleTags': styleTags,
      'isPaid': isPaid,
      'barcode': barcode,
      'color': color,
    };
  }

  Product copyWith({bool? isPaid}) {
    return Product(
      uid: uid,
      name: name,
      price: price,
      size: size,
      priceText: priceText,
      imageUrl: imageUrl,
      description: description,
      category: category,
      styleTags: styleTags,
      isPaid: isPaid ?? this.isPaid,
      barcode: barcode,
      color: color,
    );
  }

  @override
  bool operator ==(Object other) => other is Product && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}
