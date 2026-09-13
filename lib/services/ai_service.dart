import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/product.dart';

class KombinAlternative {
  final List<Product> products;
  final String aiExplanation;
  final Map<String, dynamic> popularity;

  const KombinAlternative({
    required this.products,
    required this.aiExplanation,
    required this.popularity,
  });
}

/// Render sunucusundan dönen kombin önerisi sonucu
class KombinResult {
  final String aiExplanation;
  final List<Product> recommendations;
  final Map<String, dynamic> appliedFilters;
  final Map<String, dynamic> popularity;
  /// Tüm detaylı alternatif kombinler
  final List<KombinAlternative> alternatives;

  const KombinResult({
    required this.aiExplanation,
    required this.recommendations,
    required this.appliedFilters,
    this.popularity = const {},
    this.alternatives = const [],
  });
}

/// Zincirleme try-on adım sonucu
class TryOnStepResult {
  final int step;
  final String garmentName;
  final String imageBase64;

  const TryOnStepResult({
    required this.step,
    required this.garmentName,
    required this.imageBase64,
  });
}

/// Zincirleme try-on tam sonucu
class ChainTryOnResult {
  final String finalImageBase64;
  final List<TryOnStepResult> steps;
  final String message;

  const ChainTryOnResult({
    required this.finalImageBase64,
    required this.steps,
    required this.message,
  });
}

class AiService {
  /// Metin tabanlı kombin önerisi — Render sunucusuna gider
  Future<KombinResult> getKombinSuggestions({
    required String userText,
    required List<Product> cartItems,
    String gender = '',
  }) async {
    final cartJson = cartItems.map((p) => {
      'id': p.uid,
      'name': p.name,
      'category': p.category,
      'styleTags': p.styleTags,
      'price': p.price,
    }).toList();

    final response = await _postWithRetry(
      AppConstants.kombinEndpoint,
      body: {
        'user_text': userText,
        'cart_items': cartJson,
        'gender': gender,
      },
    );

    return _parseKombinResponse(response);
  }

  /// Görsel tabanlı kombin önerisi — Render sunucusuna gider
  Future<KombinResult> getVisionSuggestions({
    required Uint8List imageBytes,
    required String mimeType,
    String? userText,
    required List<Product> cartItems,
    String gender = '',
  }) async {
    final base64Image = base64Encode(imageBytes);

    final cartJson = cartItems.map((p) => {
      'id': p.uid,
      'name': p.name,
      'category': p.category,
      'styleTags': p.styleTags,
      'price': p.price,
    }).toList();

    final response = await _postWithRetry(
      AppConstants.visionEndpoint,
      body: {
        'image_base64': base64Image,
        'mime_type': mimeType,
        'user_text': userText ?? '',
        'cart_items': cartJson,
        'gender': gender,
      },
    );

    return _parseKombinResponse(response);
  }

  /// Zincirleme sanal deneme — Birden fazla kıyafeti sırayla giydirir
  Future<ChainTryOnResult> chainedTryOn({
    required Uint8List personImageBytes,
    required List<Product> garments,
  }) async {
    final personBase64 = base64Encode(personImageBytes);

    final garmentList = garments.map((p) => {
      'image_url': p.imageUrl,
      'name': p.name,
      'description': _buildGarmentDescription(p),
      'category': p.category,
    }).toList();

    final response = await _postWithRetry(
      AppConstants.chainTryOnEndpoint,
      body: {
        'person_image_base64': personBase64,
        'garments': garmentList,
      },
      timeoutSeconds: 300, // Zincirleme işlem uzun sürebilir
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Sanal deneme başarısız.');
    }

    final steps = (data['steps'] as List).map((s) => TryOnStepResult(
      step: s['step'],
      garmentName: s['garment_name'] ?? '',
      imageBase64: s['image_base64'] ?? '',
    )).toList();

    return ChainTryOnResult(
      finalImageBase64: data['final_image_base64'] ?? '',
      steps: steps,
      message: data['message'] ?? '',
    );
  }

  /// Tek adım sanal deneme — Bir kişi fotoğrafına tek bir kıyafet giydirir
  /// Her adımın sonucu bir sonraki adımın girdisi olarak kullanılır (zincirleme)
  Future<String> singleStepTryOn({
    required String personImageBase64,
    required Product garment,
  }) async {
    final response = await _postWithRetry(
      AppConstants.stepTryOnEndpoint,
      body: {
        'person_image_base64': personImageBase64,
        'garment_image_url': garment.imageUrl,
        'garment_description': _buildGarmentDescription(garment),
        'category': garment.category,
      },
      timeoutSeconds: 180,
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Sanal deneme başarısız.');
    }

    return data['result_image_base64'] ?? '';
  }

  /// Kıyafet açıklamasını oluşturur — HuggingFace'in doğru parçaya odaklanması için
  String _buildGarmentDescription(Product product) {
    final cat = product.category.toLowerCase();
    final desc = product.description;

    // Kategori bazlı detaylı açıklama + vücut bölgesi
    final Map<String, String> categoryDesc = {
      'tisort': 'A top/t-shirt worn on the UPPER BODY (torso area only, from shoulders to waist). Place this garment ONLY on the upper torso. Do NOT modify pants or shoes.',
      'pantolon': 'Pants/trousers worn on the LOWER BODY (legs only, from waist to ankles). Place this garment ONLY on the legs. Do NOT modify any upper body clothing or shoes.',
      'elbise': 'A dress that covers from shoulders down to knees or ankles (FULL BODY garment). This is a long garment that replaces both top and bottom. Maintain the full length of the dress as shown in the garment image.',
      'ayakkabi': 'Shoes/footwear worn ONLY on the FEET area. Place this ONLY on feet. Do NOT modify any clothing above the ankles.',
    };

    String description = categoryDesc[cat] ?? 'A garment piece';

    // Ürün açıklaması varsa ekle
    if (desc.isNotEmpty) {
      description += ' Product details: $desc.';
    }

    // Stil etiketleri
    final tags = product.styleTags.take(4).join(', ');
    if (tags.isNotEmpty) {
      description += ' Style: $tags.';
    }

    return description;
  }

  /// Ortak POST isteği + Retry mantığı
  Future<http.Response> _postWithRetry(
    String url, {
    required Map<String, dynamic> body,
    int timeoutSeconds = 60,
  }) async {
    int retryCount = 0;
    const int maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(Duration(seconds: timeoutSeconds));

        if (response.statusCode == 200) {
          return response;
        }

        // 429 Rate Limit — Bekle ve tekrar dene
        if (response.statusCode == 429 && retryCount < maxRetries) {
          retryCount++;
          await Future.delayed(Duration(seconds: 2 * retryCount));
          continue;
        }

        // Diğer hatalar
        final errorMsg = _parseError(response.body);
        throw Exception('Sunucu hatası (${response.statusCode}): $errorMsg');
      } catch (e) {
        if (retryCount >= maxRetries) rethrow;
        retryCount++;
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    throw Exception('Sunucuya bağlanılamadı.');
  }

  /// Kombin yanıtını parse et
  KombinResult _parseKombinResponse(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? data['detail'] ?? 'Bilinmeyen hata');
    }

    List<Product> _parseProductList(List<dynamic> rawList) {
      final list = <Product>[];
      for (final item in rawList) {
        try {
          list.add(Product(
            uid: item['id'] ?? '',
            name: item['name'] ?? '',
            price: (item['price'] ?? 0).toDouble(),
            size: item['size'] ?? '',
            priceText: item['priceText'] ?? '',
            imageUrl: item['imageUrl'] ?? '',
            description: item['description'] ?? '',
            category: item['category'] ?? '',
            styleTags: List<String>.from(item['styleTags'] ?? []),
            isPaid: false,
          ));
        } catch (e) {
          print('Rürün parse hatası: $e');
        }
      }
      return list;
    }

    final alternatives = <KombinAlternative>[];
    final rawResults = data['results'] as List?;
    if (rawResults != null && rawResults.isNotEmpty) {
      for (final raw in rawResults) {
        alternatives.add(KombinAlternative(
          products: _parseProductList((raw['products'] as List?) ?? []),
          aiExplanation: raw['ai_explanation'] ?? '',
          popularity: Map<String, dynamic>.from(raw['popularity'] ?? {}),
        ));
      }
    }

    return KombinResult(
      aiExplanation: alternatives.isNotEmpty ? alternatives.first.aiExplanation : '',
      recommendations: alternatives.isNotEmpty ? alternatives.first.products : [],
      appliedFilters: Map<String, dynamic>.from(data['applied_filters'] ?? {}),
      popularity: alternatives.isNotEmpty ? alternatives.first.popularity : {},
      alternatives: alternatives,
    );
  }

  String _parseError(String body) {
    try {
      final json = jsonDecode(body);
      return json['detail'] ?? json['message'] ?? body;
    } catch (_) {
      return body;
    }
  }
}
