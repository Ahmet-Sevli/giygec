import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../providers/cart_provider.dart';
import '../providers/outfit_provider.dart';
import '../models/product.dart';
import '../services/ai_service.dart';
import '../widgets/product_card.dart';
import '../widgets/voice_assistant_widget.dart';
import 'virtual_tryon_screen.dart';

class AiConsultantScreen extends ConsumerStatefulWidget {
  const AiConsultantScreen({super.key});

  @override
  ConsumerState<AiConsultantScreen> createState() => _AiConsultantScreenState();
}

class _AiConsultantScreenState extends ConsumerState<AiConsultantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _visionTextController = TextEditingController();
  final AiService _aiService = AiService();
  final ImagePicker _imagePicker = ImagePicker();
  final VoiceAssistantController _voiceController = VoiceAssistantController();
  final VoiceAssistantController _visionVoiceController = VoiceAssistantController();

  bool _isLoading = false;
  bool _isVoiceEnabled = true;
  List<Product> _recommendations = [];
  String? _aiExplanation;
  String? _errorMessage;
  String _selectedGender = 'kadın';
  String? _popularityMessage;
  // #14: Alternatif kombinler için
  int _kombinOffset = 0;
  List<KombinAlternative> _allCombinations = [];
  // #12: Vision mode için fotoğraf ve prompt ayrı yönetilir
  Uint8List? _visionImageBytes;
  String? _visionMimeType;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _visionTextController.dispose();
    // Stop TTS/STT to prevent setState-after-dispose crashes
    _voiceController.stop?.call();
    _visionVoiceController.stop?.call();
    super.dispose();
  }

  /// Metin/Ses Modu
  Future<void> _analyzeTextStyle() async {
    final cart = ref.read(cartProvider);
    final text = _textController.text.trim();

    if (text.isEmpty && cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir stil belirtin veya sepetinize ürün ekleyin.'),
          backgroundColor: AppTheme.accentAlt,
        ),
      );
      return;
    }

    // FIX #1: Yeni kombin gelince TTS'i durdur
    _voiceController.stop?.call();
    _visionVoiceController.stop?.call();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _aiExplanation = null;
      _recommendations = [];
      _popularityMessage = null;
      _kombinOffset = 0;
    });

    try {
      final result = await _aiService.getKombinSuggestions(
        userText: text.isNotEmpty ? text : "Sepetimle uyumlu bir kombin öner.",
        cartItems: cart,
        gender: _selectedGender,
      );

      if (!mounted) return;
      setState(() {
        _recommendations = result.recommendations;
        _aiExplanation = result.aiExplanation;
        _allCombinations = result.alternatives; // #14
        _kombinOffset = 0;
        final popMsg = result.popularity['message'] as String?;
        _popularityMessage = (popMsg != null && popMsg.isNotEmpty) ? popMsg : null;
      });

      if (result.recommendations.isEmpty) {
        final error = 'Üzgünüz, girişinize uygun bir kombin bulunamadı.';
        if (!mounted) return;
        setState(() => _errorMessage = error);
        if (_isVoiceEnabled) _voiceController.speak?.call(error);
      } else {
        // FIX #8: Daha doğal TTS metni — ürün description'larını kullan
        if (_isVoiceEnabled) {
          final ttsText = _buildNaturalTtsText(result.aiExplanation, result.recommendations);
          _voiceController.speak?.call(ttsText);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Analiz hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// FIX #8: Ürün description'larından doğal TTS metni oluştur
  String _buildNaturalTtsText(String aiExplanation, List<Product> products) {
    // Backend (AI Modeli) artık seçilen ürünlerin detaylarını inceleyip
    // tek bir akıcı, kısa özet metni döndürüyor. Bu yüzden burada tekrar 
    // her ürünün ismini veya açıklamasını eklememize gerek yok.
    if (aiExplanation.isNotEmpty) {
      return aiExplanation;
    }
    return 'Sizin için harika bir kombin seçtim.';
  }


  /// Görsel Modu
  Future<void> _analyzeImageStyle() async {
    final cart = ref.read(cartProvider);
    // FIX #12: Fotoğraf yoksa uyar
    if (_visionImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir fotoğraf çekin veya seçin.')),
      );
      return;
    }
    final userPreference = _visionTextController.text.trim();
    if (userPreference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen stil tercihlerinizi yazın, sonra analiz edin.')),
      );
      return;
    }

    // FIX #1: Yeni analiz başlayinca TTS durdur
    _voiceController.stop?.call();
    _visionVoiceController.stop?.call();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _aiExplanation = null;
      _recommendations = [];
      _popularityMessage = null;
      _kombinOffset = 0;
    });

    try {
      final result = await _aiService.getVisionSuggestions(
        imageBytes: _visionImageBytes!,
        mimeType: _visionMimeType ?? 'image/jpeg',
        userText: userPreference.isNotEmpty ? userPreference : null,
        cartItems: cart,
        gender: _selectedGender,
      );

      if (!mounted) return;
      setState(() {
        _recommendations = result.recommendations;
        _aiExplanation = result.aiExplanation;
        _allCombinations = result.alternatives; // #14
        _kombinOffset = 0;
        final popMsg = result.popularity['message'] as String?;
        _popularityMessage = (popMsg != null && popMsg.isNotEmpty) ? popMsg : null;
      });

      if (result.recommendations.isEmpty) {
        final error = 'Üzgünüz, fotoğrafınıza uygun bir parça bulunamadı.';
        if (!mounted) return;
        setState(() => _errorMessage = error);
        if (_isVoiceEnabled) _visionVoiceController.speak?.call(error);
      } else {
        if (_isVoiceEnabled) {
          final ttsText = _buildNaturalTtsText(result.aiExplanation, result.recommendations);
          _visionVoiceController.speak?.call(ttsText);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Görsel hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// FIX #14: Sonraki/önceki kombinasyona geç
  void _switchToCombo(int newOffset) {
    if (_allCombinations.isEmpty) return;
    final idx = newOffset.clamp(0, _allCombinations.length - 1);
    
    _voiceController.stop?.call();
    _visionVoiceController.stop?.call();
    
    setState(() {
      _kombinOffset = idx;
      final alt = _allCombinations[idx];
      _recommendations = alt.products;
      _aiExplanation = alt.aiExplanation;
      final popMsg = alt.popularity['message'] as String?;
      _popularityMessage = (popMsg != null && popMsg.isNotEmpty) ? popMsg : null;
    });

    // Sesli asistanın yeni kombin için de çalışması
    if (_isVoiceEnabled) {
      final ttsText = _buildNaturalTtsText(_aiExplanation ?? '', _recommendations);
      if (_tabController.index == 0) {
        _voiceController.speak?.call(ttsText);
      } else {
        _visionVoiceController.speak?.call(ttsText);
      }
    }
  }

  Future<void> _pickVisionImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.textPrimary),
              title: const Text('Kamera', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _processImagePick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.textPrimary),
              title: const Text('Galeri', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _processImagePick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImagePick(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final mime = image.path.endsWith('.png') ? 'image/png' : 'image/jpeg';
      setState(() {
        _visionImageBytes = bytes;
        _visionMimeType = mime;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D12), Color(0xFF12121C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              const SizedBox(height: 16),
              _buildTabBar(),
              const SizedBox(height: 20),
              Expanded(
                child: IndexedStack(
                  index: _activeTab,
                  children: [
                    _buildTextMode(),
                    _buildVisionMode(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          ),
          const Expanded(
            child: Text('AI Stil Danışmanı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
          // FIX #9: Ses butonu TTS'i de durdursun
          IconButton(
            icon: Icon(
              _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: _isVoiceEnabled ? AppTheme.accentAlt : AppTheme.textMuted,
            ),
            onPressed: () {
              if (_isVoiceEnabled) {
                // Sesi kapat ve varsa konuşmayı durdur
                _voiceController.stop?.call();
                _visionVoiceController.stop?.call();
              }
              setState(() => _isVoiceEnabled = !_isVoiceEnabled);
            },
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: AppTheme.buttonRadius),
      child: Row(
        children: [
          _buildTabBtn(0, Icons.text_fields, 'Metin/Ses'),
          _buildTabBtn(1, Icons.camera_alt, 'Görsel Analiz'),
        ],
      ),
    );
  }

  Widget _buildTabBtn(int idx, IconData icon, String label) {
    final active = _activeTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: active ? Colors.white : AppTheme.textMuted, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: 2,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Örn: Yazlık şık bir kombin istiyorum',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              VoiceAssistantWidget(
                controller: _voiceController,
                onResult: (text) {
                  _textController.text = text;
                  _analyzeTextStyle();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGenderSelector(),
          const SizedBox(height: 16),
          _buildActionButton('Kombin Öner', _analyzeTextStyle),
          const SizedBox(height: 24),
          _buildResults(),
        ],
      ),
    );
  }

  Widget _buildVisionMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _visionTextController,
                  maxLines: 2,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Tarzını buraya yaz (zorunlu)...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              VoiceAssistantWidget(
                controller: _visionVoiceController,
                onResult: (text) {
                  setState(() => _visionTextController.text = text);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGenderSelector(),
          const SizedBox(height: 16),
          // FIX #12: Önce fotoğraf seç, sonra analiz et
          GestureDetector(
            onTap: _pickVisionImage,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: _visionImageBytes != null ? 12 : 40),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: AppTheme.cardRadius,
                border: Border.all(
                  color: _visionImageBytes != null
                      ? AppTheme.primaryColor.withOpacity(0.5)
                      : AppTheme.dividerColor,
                  width: _visionImageBytes != null ? 2 : 1,
                ),
              ),
              child: _visionImageBytes != null
                  ? Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_visionImageBytes!, height: 180, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _pickVisionImage,
                          icon: const Icon(Icons.camera_alt_rounded, size: 16),
                          label: const Text('Fotoğrafı Değiştir'),
                        ),
                      ],
                    )
                  : const Column(
                      children: [
                        Icon(Icons.camera_alt_rounded, color: AppTheme.accentAlt, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'Fotoğraf Seç veya Çek',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Fotoğrafı seçtiken sonra stilinizi yazıp analiz edin',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // FIX #12: Analiz butonu sadece fotoğraf ve prompt dolu olunca aktif
          _buildActionButton('Analiz Et & Öner', _analyzeImageStyle),
          const SizedBox(height: 24),
          _buildResults(),
        ],
      ),
    );
  }
  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.buttonRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 10),
          const Text('Kim için?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                _buildGenderChip('Kadın', 'kadın'),
                const SizedBox(width: 8),
                _buildGenderChip('Erkek', 'erkek'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label, String value) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? null : Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: _isLoading ? null : AppTheme.primaryGradient,
          color: _isLoading ? AppTheme.cardBgLight : null,
          borderRadius: AppTheme.buttonRadius,
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    if (_recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Açıklaması
        if (_aiExplanation != null && _aiExplanation!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.accentColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.accentAlt, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _aiExplanation!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Popülerlik mesajı
        if (_popularityMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.12),
                  Colors.orange.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _popularityMessage!,
                    style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '✨ Önerilen Kombin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            // FIX #14: Kombin Yenile Butonu
            TextButton.icon(
              onPressed: () {
                if (_allCombinations.length > 1) {
                  final nextOffset = (_kombinOffset + 1) % _allCombinations.length;
                  _switchToCombo(nextOffset);
                } else {
                  // Tekrar API'yi çağır (zaten text/görsel moduna göre karar veriyoruz)
                  if (_tabController.index == 0) {
                    _analyzeTextStyle();
                  } else {
                    _analyzeImageStyle();
                  }
                }
              },
              icon: const Icon(Icons.refresh, color: AppTheme.accentColor, size: 20),
              label: Text(
                _allCombinations.length > 1 
                  ? 'Yenile (${_kombinOffset + 1}/${_allCombinations.length})'
                  : 'Yeniden Üret',
                style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recommendations.length,
            itemBuilder: (context, index) => ProductCard(
              product: _recommendations[index],
              showRemoveButton: false,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _recommendations[index].imageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // FIX #3+#13: Kombini Kaydet — duplicate engel + sepet ürünlerini de ekle
        _buildActionButton('💾 Kombini Kaydet', () async {
          final cart = ref.read(cartProvider);
          // Sepetteki ürünleri de dahil et (duplicate olmamak için)
          final allProducts = [
            ...cart.where((c) => !_recommendations.any((r) => r.uid == c.uid)),
            ..._recommendations,
          ];
          final saved = await ref.read(outfitProvider.notifier).saveOutfit(allProducts);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(saved
                    ? 'Kombin profilinize kaydedildi! ✅'
                    : 'Bu kombin zaten kaydedilmiş! ⚠️'),
                backgroundColor: saved ? Colors.green : Colors.orange,
              ),
            );
          }
        }),
        const SizedBox(height: 12),

        // Sanal Kabin (Kombini Dene) butonu
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VirtualTryOnScreen(recommendations: _recommendations),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: AppTheme.buttonRadius,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  '👕 Kombini Üzerimde Dene',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
