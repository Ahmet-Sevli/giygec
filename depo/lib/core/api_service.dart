import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class DepoApiService {
  static const String _base = DepoConstants.baseUrl;

  // ── NFC – Barkod Eşleştir ──
  static Future<Map<String, dynamic>> nfcBarkodEsle({
    required String uid,
    required String barkod,
  }) async {
    final res = await http.post(
      Uri.parse('$_base${DepoConstants.nfcBarkodEsle}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid, 'barkod': barkod}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── NFC Bilgi Getir ──
  static Future<Map<String, dynamic>> nfcBilgi(String uid) async {
    final res = await http.get(
      Uri.parse('$_base${DepoConstants.nfcBilgi}?uid=${Uri.encodeComponent(uid)}'),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── NFC Yeniden Eşleştir ──
  static Future<Map<String, dynamic>> nfcYenidenEsle({
    required String uid,
    required String barkod,
  }) async {
    final res = await http.post(
      Uri.parse('$_base${DepoConstants.nfcYenidenEsle}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid, 'barkod': barkod}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Stok – NFC ile ──
  static Future<Map<String, dynamic>> stokNfc(String uid) async {
    final res = await http.get(
      Uri.parse('$_base${DepoConstants.stokNfc}?uid=${Uri.encodeComponent(uid)}'),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Stok – Barkod ile ──
  static Future<Map<String, dynamic>> stokBarkod(String barkod) async {
    final res = await http.get(
      Uri.parse('$_base${DepoConstants.stokBarkod}?barkod=${Uri.encodeComponent(barkod)}'),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Loglar ──
  static Future<Map<String, dynamic>> getLogs({String? logType, int limit = 50}) async {
    String url = '$_base${DepoConstants.logs}?limit=$limit';
    if (logType != null && logType.isNotEmpty) {
      url += '&log_type=${Uri.encodeComponent(logType)}';
    }
    final res = await http.get(Uri.parse(url));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── NFC Kayıt ──
  static Future<Map<String, dynamic>> nfcKayit(String uid) async {
    final res = await http.post(
      Uri.parse('$_base${DepoConstants.nfcKayit}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── STOK ÖZET (NFC Kayıtlı Ürün Sayısı) ──
  static Future<int> getStokOzet() async {
    try {
      final res = await http.get(Uri.parse('$_base${DepoConstants.stokOzet}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'ok') {
          return data['toplam_nfc_urun'] ?? 0;
        }
        throw data['detail'] ?? 'Bilinmeyen hata';
      }
      throw 'Sunucu Hatası: ${res.statusCode}';
    } catch (e) {
      throw 'Bağlantı hatası: $e';
    }
  }
  // ── Barkod Doğrula (DB'de kayıtlı mı?) ──
  static Future<bool> barkodDogrula(String barkod) async {
    try {
      final res = await http.get(
        Uri.parse('$_base${DepoConstants.barkodDogrula}?barkod=${Uri.encodeComponent(barkod)}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['status'] == 'ok' && data['gecerli'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
