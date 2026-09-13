class DepoConstants {
  DepoConstants._();

  // Render sunucu adresi — ana uygulama ile aynı sunucu
  static const String baseUrl = 'https://giygec-render-nfc.onrender.com';

  // Endpoint paths
  static const String nfcBarkodEsle = '/depo/nfc-barkod-esle';
  static const String nfcBilgi = '/depo/nfc-bilgi';
  static const String nfcYenidenEsle = '/depo/nfc-yeniden-esle';
  static const String stokNfc = '/depo/stok-nfc';
  static const String stokBarkod = '/depo/stok-barkod';
  static const String logs = '/depo/logs';
  static const String nfcKayit = '/depo/nfc-kayit';
  static const String stokOzet = '/depo/stok-ozet';
  static const String barkodDogrula = '/depo/barkod-dogrula';

  // Firebase collections
  static const String productsCollection = 'products';
  static const String barcodesCollection = 'barcodes';
  static const String catalogCollection = 'catalog';
  static const String logsCollection = 'logs';

  // Default barcode (unmapped)
  static const String defaultBarkod = '0000000000000';
}
