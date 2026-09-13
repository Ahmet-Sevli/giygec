class AppConstants {
  AppConstants._();

  // ── Render.com Sunucu (API Anahtarları Güvenle Sunucuda) ──
  static const String renderBaseUrl = 'https://giygec-render-nfc.onrender.com';
  static const String kombinEndpoint = '$renderBaseUrl/kombin-oner';
  static const String visionEndpoint = '$renderBaseUrl/vision-analiz';
  static const String tryOnEndpoint = '$renderBaseUrl/virtual-try-on';
  static const String chainTryOnEndpoint = '$renderBaseUrl/virtual-try-on-chain';
  static const String stepTryOnEndpoint = '$renderBaseUrl/virtual-try-on-step';

  // ── Firestore Collections ──
  static const String productsCollection = 'products';
  static const String receiptsCollection = 'receipts';

  // ── Animation Durations ──
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);
  static const Duration animVerySlow = Duration(milliseconds: 1000);

  // ── Moda Bilgileri (Bekleme Ekranında Gösterilecek) ──
  static const List<String> fashionTips = [
    '💡 60-30-10 Kuralı: Kombinde %60 ana renk, %30 ikincil renk, %10 vurgu rengi olmalı.',
    '👗 Elbise giydiysen ayrıca pantolon/tişört ekleme — elbise tek başına yeterli!',
    '📐 Orantı Kuralı: Yüksek bel pantolon + kısa üst = bacaklar daha uzun görünür.',
    '🎨 Bir kombinde en fazla 1 desenli parça olmalı. İkisi birden gözü yorar.',
    '⚖️ Üst oversize ise alt dar, alt geniş ise üst fitted olmalı — hacim dengesi!',
    '👔 Smart Casual: Temiz beyaz sneaker OK, ama koşu ayakkabısı NO.',
    '🌿 Bohem tarz: Toprak tonları, çiçek desenleri ve doğal kumaşlar harika uyum sağlar.',
    '🖤 Siyah her şeyle uyumludur — ama tamamını siyah giyersen monoton olabilir.',
    '👠 Ayakkabı, kombinin %10 vurgu rengini taşıyarak tarzını tamamlar.',
    '🧵 Keten ve şifon yaz için, kadife ve yün kış için ideal kumaşlardır.',
    '🎯 Business Formal: Siyah, lacivert, füme. Minimal desen, maximum etki.',
    '✨ Aksesuarlar kombini tamamlar ama abartma — az çoktur!',
  ];
}
