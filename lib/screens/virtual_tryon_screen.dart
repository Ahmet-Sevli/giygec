import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/product.dart';
import '../providers/outfit_provider.dart';
import '../services/ai_service.dart';

class VirtualTryOnScreen extends ConsumerStatefulWidget {
  final List<Product> recommendations;

  const VirtualTryOnScreen({
    super.key,
    required this.recommendations,
  });

  @override
  ConsumerState<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends ConsumerState<VirtualTryOnScreen>
    with TickerProviderStateMixin {
  final AiService _aiService = AiService();
  final ImagePicker _imagePicker = ImagePicker();

  // Seçim durumları
  final List<int> _selectedIndices = [];
  Uint8List? _personImageBytes;
  bool _personPhotoTaken = false;

  // İşlem durumları
  bool _isProcessing = false;
  int _currentStep = 0;
  int _totalSteps = 0;
  String _currentGarmentName = '';

  // Sonuç
  bool _allStepsComplete = false;
  String? _resultImageBase64;
  List<TryOnStepResult>? _stepResults;

  // Moda ipuçları animasyonu
  late AnimationController _tipFadeController;
  late Animation<double> _tipFadeAnimation;
  int _currentTipIndex = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Tüm ürünleri başlangıçta seçili yap
    for (int i = 0; i < widget.recommendations.length; i++) {
      _selectedIndices.add(i);
    }
    _currentTipIndex = _random.nextInt(AppConstants.fashionTips.length);

    _tipFadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _tipFadeAnimation = CurvedAnimation(
      parent: _tipFadeController,
      curve: Curves.easeInOut,
    );
    _tipFadeController.forward();
  }

  /// Sonuç görselini galeriye kaydet
  Future<void> _saveToGallery() async {
    if (_resultImageBase64 == null) return;
    try {
      final bytes = base64Decode(_resultImageBase64!);
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Galeri izni verilmedi.')),
            );
          }
          return;
        }
      }
      await Gal.putImageBytes(bytes, album: 'GiyGeç');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görsel galeriye kaydedildi ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    }
  }

  /// Mevcut kombinasyonu profile kaydet
  Future<void> _saveOutfit(WidgetRef? unused) async {
    final products = _selectedIndices.map((i) => widget.recommendations[i]).toList();
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilecek ürün seçili değil.')),
      );
      return;
    }
    final saved = await ref.read(outfitProvider.notifier).saveOutfit(products);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? 'Kombin kaydedildi ✓' : 'Bu kombin zaten kayıtlı.'),
          backgroundColor: saved ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tipFadeController.dispose();
    super.dispose();
  }

  /// Moda ipucunu değiştir
  void _nextTip() {
    _tipFadeController.reverse().then((_) {
      setState(() {
        _currentTipIndex = _random.nextInt(AppConstants.fashionTips.length);
      });
      _tipFadeController.forward();
    });
  }

  /// Kullanıcı fotoğrafı çek
  Future<void> _takePersonPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() {
        _personImageBytes = bytes;
        _personPhotoTaken = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf çekilemedi: $e')),
        );
      }
    }
  }

  /// Galeriden seç
  Future<void> _pickPersonPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() {
        _personImageBytes = bytes;
        _personPhotoTaken = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
        );
      }
    }
  }

  /// Kategori sıralama önceliği: üst giyim → alt giyim → ayakkabı
  static const _categoryOrder = {
    'tisort': 0, 'elbise': 0, 'gömlek': 0, 'kazak': 0, 'sweatshirt': 0, 'bluz': 0,
    'pantolon': 1, 'etek': 1, 'şort': 1,
    'ayakkabi': 2,
  };

  int _getCategoryOrder(String category) {
    return _categoryOrder[category.toLowerCase()] ?? 1;
  }

  /// Zincirleme try-on başlat
  Future<void> _startTryOn() async {
    if (_personImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir fotoğraf çekin veya galeriden seçin.'),
          backgroundColor: AppTheme.accentAlt,
        ),
      );
      return;
    }

    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen denemek istediğiniz en az bir parçayı seçin.'),
          backgroundColor: AppTheme.accentAlt,
        ),
      );
      return;
    }

    final selectedProducts = _selectedIndices
        .map((i) => widget.recommendations[i])
        .toList();

    // Kategori sırasına göre sırala: üst giyim → alt giyim → ayakkabı
    selectedProducts.sort((a, b) =>
      _getCategoryOrder(a.category).compareTo(_getCategoryOrder(b.category)));

    setState(() {
      _isProcessing = true;
      _allStepsComplete = false;
      _totalSteps = selectedProducts.length;
      _currentStep = 1;
      _currentGarmentName = selectedProducts.first.name;
      _resultImageBase64 = null;
      _stepResults = [];
    });

    // İpucunu döngüsünü başlat
    _startTipRotation();

    // Kullanıcı fotoğrafını base64'e çevir
    String currentPersonBase64 = base64Encode(_personImageBytes!);

    for (int i = 0; i < selectedProducts.length; i++) {
      final product = selectedProducts[i];

      if (!mounted) return;
      // FIX #6: setState'i sadece gerekli alanlar için güncelle, _resultImageBase64 değişmesin
      setState(() {
        _currentStep = i + 1;
        _currentGarmentName = product.name;
      });

      try {
        final resultBase64 = await _aiService.singleStepTryOn(
          personImageBase64: currentPersonBase64,
          garment: product,
        );

        if (!mounted) return;

        currentPersonBase64 = resultBase64;

        setState(() {
          _resultImageBase64 = resultBase64;
          _stepResults!.add(TryOnStepResult(
            step: i + 1,
            garmentName: product.name,
            imageBase64: resultBase64,
          ));
        });
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} giydirilemedi: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        break;
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _allStepsComplete = true;
      });
    }
  }

  void _startTipRotation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!_isProcessing || !mounted) return false;
      _nextTip();
      return _isProcessing;
    });
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
              Expanded(
                // FIX #6: AnimatedSwitcher titremeyı önler
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _resultImageBase64 != null
                      ? _buildResultView()
                      : _isProcessing
                          ? _buildProcessingView()
                          : _buildSelectionView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FIX #7: Tam ekran görsel izleyici
  void _showFullScreen(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            child: Image.memory(imageBytes, fit: BoxFit.contain),
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
            child: Text(
              'Sanal Kabin',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.checkroom, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ─── SEÇIM GÖRÜNÜMÜ ───
  Widget _buildSelectionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Fotoğraf Çek/Seç
          const Text(
            '📸 Fotoğrafınız',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kombini üzerinizde görmek için tam boy bir fotoğraf çekin veya galeriden seçin.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),

          if (_personPhotoTaken && _personImageBytes != null)
            _buildPersonPreview()
          else
            _buildPhotoButtons(),

          const SizedBox(height: 28),

          // 2. Ürün Seçimi
          const Text(
            '👗 Giyme Sırasına Göre Parça Seçin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Parçalara dokunma sıranız giyme sırasını belirler. Örn: önce tişört, sonra pantolon.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),

          ...List.generate(widget.recommendations.length, (index) {
            final product = widget.recommendations[index];
            final isSelected = _selectedIndices.contains(index);
            return _buildSelectableProduct(product, index, isSelected);
          }),

          const SizedBox(height: 24),

          // Başlat butonu
          GestureDetector(
            onTap: _startTryOn,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: (_personPhotoTaken && _selectedIndices.isNotEmpty)
                    ? AppTheme.accentGradient
                    : null,
                color: (_personPhotoTaken && _selectedIndices.isNotEmpty)
                    ? null
                    : AppTheme.cardBgLight,
                borderRadius: AppTheme.buttonRadius,
                boxShadow: (_personPhotoTaken && _selectedIndices.isNotEmpty)
                    ? [
                        BoxShadow(
                          color: AppTheme.accentColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: (_personPhotoTaken && _selectedIndices.isNotEmpty)
                        ? Colors.white
                        : AppTheme.textMuted,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kombini Dene (${_selectedIndices.length} parça)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: (_personPhotoTaken && _selectedIndices.isNotEmpty)
                          ? Colors.white
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPhotoButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _takePersonPhoto,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: AppTheme.cardRadius,
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fotoğraf Çek',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _pickPersonPhoto,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: AppTheme.cardRadius,
                border: Border.all(color: AppTheme.dividerColor, width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBgLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.textSecondary, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Galeriden Seç',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonPreview() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: AppTheme.cardRadius,
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              _personImageBytes!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _personImageBytes = null;
                _personPhotoTaken = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Fotoğraf hazır', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableProduct(Product product, int index, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIndices.remove(index);
          } else {
            _selectedIndices.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : AppTheme.cardBg,
          borderRadius: AppTheme.buttonRadius,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.5) : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.primaryGradient : null,
                color: isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected ? null : Border.all(color: AppTheme.textMuted, width: 1.5),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),

            // Ürün resmi
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: product.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppTheme.cardBgLight),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.cardBgLight,
                          child: const Icon(Icons.image_not_supported, color: AppTheme.textMuted, size: 24),
                        ),
                      )
                    : Container(
                        color: AppTheme.cardBgLight,
                        child: const Icon(Icons.checkroom, color: AppTheme.textMuted, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Ürün bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            // Sıra numarası
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${_selectedIndices.indexOf(index) + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── İŞLEM GÖRÜNÜMÜ (Bekleme Ekranı) ───
  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsating avatar
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.1),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.checkroom, color: Colors.white, size: 48),
                  ),
                );
              },
              onEnd: () => setState(() {}), // Restart animation
            ),
            const SizedBox(height: 32),

            // Adım bilgisi
            Text(
              'Kıyafet Giydiriliyor...',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_currentStep / $_totalSteps parça işleniyor',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Progress bar
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.cardBgLight,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _totalSteps > 0 ? _currentStep / _totalSteps : 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Moda ipucu
            FadeTransition(
              opacity: _tipFadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(color: AppTheme.dividerColor.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Biliyor muydun?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentAlt,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppConstants.fashionTips[_currentTipIndex],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SONUÇ GÖRÜNÜMÜ ───
  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Durum mesajı — işlem devam ediyorsa veya tamamsa
          if (_isProcessing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentColor.withOpacity(0.15),
                    AppTheme.accentColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$_currentStep/$_totalSteps — $_currentGarmentName giydiriliyor...',
                          style: TextStyle(color: AppTheme.accentColor, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _totalSteps > 0 ? _currentStep / _totalSteps : 0,
                      backgroundColor: AppTheme.cardBgLight,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.15),
                    Colors.green.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _allStepsComplete
                          ? 'Tüm parçalar giydirildi! İşte kombininiz 👇'
                          : 'İşte üzerinizdeki görünüm 👇',
                      style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Final sonuç resmi — FIX #7: Dokunca tam ekran açılır
          GestureDetector(
            onTap: () => _showFullScreen(context, base64Decode(_resultImageBase64!)),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: AppTheme.cardRadius,
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  base64Decode(_resultImageBase64!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Adım adım sonuçlar (opsiyonel, kaydırılabilir)
          if (_stepResults != null && _stepResults!.length > 1) ...[
            const Text(
              'Adım Adım Görünüm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _stepResults!.length,
                itemBuilder: (context, index) {
                  final step = _stepResults![index];
                  final imgBytes = base64Decode(step.imageBase64);
                  // FIX #7: Adım görseline dokununca tam ekran
                  return GestureDetector(
                    onTap: () => _showFullScreen(context, imgBytes),
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                              child: Image.memory(
                                imgBytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                            ),
                            child: Text(
                              '· ${step.step}. ${step.garmentName}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Galeri ve Kombin Kaydet butonları
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _saveToGallery(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppTheme.buttonRadius,
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save_alt_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Galeriye Kaydet',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _saveOutfit(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: AppTheme.buttonRadius,
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Kombini Kaydet',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tekrar dene butonu
          GestureDetector(
            onTap: () {
              setState(() {
                _resultImageBase64 = null;
                _stepResults = null;
                _allStepsComplete = false;
                _personImageBytes = null;
                _personPhotoTaken = false;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBgLight,
                borderRadius: AppTheme.buttonRadius,
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: const Center(
                child: Text(
                  '🔄 Farklı Fotoğrafla Tekrar Dene',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
