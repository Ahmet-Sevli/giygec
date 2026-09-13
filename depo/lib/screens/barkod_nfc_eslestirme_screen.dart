import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_service.dart';
import '../core/nfc_service.dart';
import '../core/theme.dart';

class BarkodNfcEslestirmeScreen extends StatefulWidget {
  const BarkodNfcEslestirmeScreen({super.key});

  @override
  State<BarkodNfcEslestirmeScreen> createState() =>
      _BarkodNfcEslestirmeScreenState();
}

class _BarkodNfcEslestirmeScreenState
    extends State<BarkodNfcEslestirmeScreen> {
  final DepoNfcService _nfcService = DepoNfcService();

  // State
  String? _scannedBarkod;
  bool _nfcActive = false;
  bool _scanning = false;
  int _eslestirilenCount = 0;
  List<String> _eslestirilenUids = [];
  String _statusMessage = 'Barkod okutarak başlayın';
  bool _isLoading = false;
  int? _totalNfcProducts;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _fetchTotalNfcProducts();
  }

  Future<void> _fetchTotalNfcProducts() async {
    try {
      final total = await DepoApiService.getStokOzet();
      setState(() {
        _totalNfcProducts = total;
      });
    } catch (e) {
      // Sessizce yoksay veya logla
      print("Toplam ürün çekilirken hata: $e");
    }
  }

  // Ses
  static const _beepChannel = MethodChannel('com.giygec.depo/beep');

  @override
  void dispose() {
    if (_nfcActive) _nfcService.stopSession();
    super.dispose();
  }

  Future<void> _playBeep() async {
    try {
      // Simple vibration as audio feedback fallback
      HapticFeedback.mediumImpact();
      // Try beep via system sounds
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  // ── ADIM 1: Barkod tara ──
  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _BarcodeScannerPage(),
      ),
    );
    if (result != null && result.isNotEmpty) {
      // DB doğrulaması
      setState(() {
        _isLoading = true;
        _statusMessage = 'Barkod kontrol ediliyor...';
      });
      final gecerli = await DepoApiService.barkodDogrula(result);
      setState(() => _isLoading = false);

      if (!gecerli) {
        setState(() {
          _scannedBarkod = null;
          _statusMessage = 'Barkod okutarak başlayın';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Geçersiz barkod! Lütfen sistemimizde kayıtlı bir ürün barkoduokutun.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      setState(() {
        _scannedBarkod = result;
        _statusMessage = 'Barkod tarandı: $result';
        _nfcActive = false;
        _eslestirilenCount = 0;
        _eslestirilenUids.clear();
      });
      _showNfcConfirmDialog(result);
    }
  }

  // ── ADIM 2: NFC eşleştirme onay ──
  void _showNfcConfirmDialog(String barkod) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: DepoTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'NFC Eşleştirme',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Taranan barkod:',
                style: GoogleFonts.inter(color: DepoTheme.textSecondary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DepoTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                barkod,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: DepoTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bu barkodu NFC etiketlerine eşleştirmek istiyor musunuz?',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // İptal: sayfayı tamamen sıfırla
              setState(() {
                _scannedBarkod = null;
                _nfcActive = false;
                _eslestirilenCount = 0;
                _eslestirilenUids.clear();
                _lastError = null;
                _statusMessage = 'İptal edildi. Barkod okutarak başlayın.';
              });
            },
            child: Text('Hayır', style: TextStyle(color: DepoTheme.error)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startNfcSession(barkod);
            },
            child: const Text('Evet, Başla'),
          ),
        ],
      ),
    );
  }

  // ── ADIM 3: NFC okuma oturumu ──
  void _startNfcSession(String barkod) {
    setState(() {
      _nfcActive = true;
      _statusMessage = 'NFC etiketlerini okutun...';
    });

    _nfcService.startContinuousSession(
      onTagRead: (uid) async {
        if (!_nfcActive) return;

        // Duplicate UID check (prevent rapid re-reads)
        if (_eslestirilenUids.contains(uid)) return;

        setState(() => _isLoading = true);

        try {
          final result = await DepoApiService.nfcBarkodEsle(
            uid: uid,
            barkod: barkod,
          );

          if (result['status'] == 'ok') {
            _eslestirilenUids.add(uid);
            setState(() {
              _eslestirilenCount++;
              _statusMessage = '$_eslestirilenCount NFC eşleştirildi ✓';
              _lastError = null;
            });
            await _playBeep();
          } else {
            setState(() {
              _lastError = result['detail'] ?? 'Hata oluştu';
            });
          }
        } catch (e) {
          setState(() {
            _lastError = 'Sunucu hatası: $e';
          });
        } finally {
          setState(() => _isLoading = false);
        }
      },
      onError: (err) {
        setState(() => _lastError = err);
      },
    );
  }

  // ── ADIM 4: Oturumu bitir ──
  void _finishSession() {
    _nfcService.stopSession();
    setState(() {
      _nfcActive = false;
      _statusMessage =
          '$_eslestirilenCount NFC etiket eşleştirildi. İşlem tamamlandı.';
    });
    _showDoneDialog();
  }

  void _showDoneDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DepoTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: DepoTheme.success, size: 28),
            const SizedBox(width: 8),
            Text('Tamamlandı!',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '$_eslestirilenCount NFC etiketi başarıyla eşleştirildi.\nBarkod: ${_scannedBarkod ?? ""}',
          style: GoogleFonts.inter(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _scannedBarkod = null;
                _eslestirilenCount = 0;
                _eslestirilenUids.clear();
                _statusMessage = 'Barkod okutarak başlayın';
              });
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DepoTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Barkod–NFC Eşleştirme',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: DepoTheme.dividerColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Toplam Ürün Bilgisi ──
            if (_totalNfcProducts != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DepoTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DepoTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory, color: DepoTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Depoda Bulunan NFC Kayıtlı Ürün: $_totalNfcProducts',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: DepoTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Status Card ──
            _StatusCard(
              barkod: _scannedBarkod,
              nfcActive: _nfcActive,
              count: _eslestirilenCount,
              message: _statusMessage,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 20),

            // ── Hata ──
            if (_lastError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DepoTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DepoTheme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: DepoTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_lastError!,
                          style: GoogleFonts.inter(
                              color: DepoTheme.error, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Eşleştirilen UIDs ──
            if (_eslestirilenUids.isNotEmpty) ...[
              Text('Eşleştirilen NFC\'ler:',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: DepoTheme.textPrimary)),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DepoTheme.dividerColor),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _eslestirilenUids.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: DepoTheme.dividerColor),
                  itemBuilder: (_, i) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.nfc,
                          color: DepoTheme.success, size: 18),
                      title: Text(_eslestirilenUids[i],
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: DepoTheme.textSecondary)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Butonlar ──
            if (!_nfcActive) ...[
              ElevatedButton.icon(
                onPressed: _scanning ? null : _openBarcodeScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(
                  _scannedBarkod == null
                      ? 'Barkod Okut'
                      : 'Yeni Barkod Okut',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DepoTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              // NFC aktif — işlemi tamamla butonu
              ElevatedButton.icon(
                onPressed: _finishSession,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  'İşlemi Tamamla',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DepoTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  _nfcService.stopSession();
                  setState(() {
                    _nfcActive = false;
                    _statusMessage = 'İptal edildi.';
                  });
                },
                icon: const Icon(Icons.stop),
                label: const Text('İptal Et'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DepoTheme.error,
                  side: const BorderSide(color: DepoTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Talimat Kartları ──
            _InstructionCard(
              step: 1,
              title: 'Barkod Okut',
              desc:
                  '"Barkod Okut" butonuna basın ve ürünün barkodunu kameraya gösterin.',
              icon: Icons.qr_code_scanner,
            ),
            const SizedBox(height: 10),
            _InstructionCard(
              step: 2,
              title: 'Onaylayın',
              desc:
                  'Barkod algılandıktan sonra NFC eşleştirmesini başlatmak için "Evet"e basın.',
              icon: Icons.thumb_up_alt_outlined,
            ),
            const SizedBox(height: 10),
            _InstructionCard(
              step: 3,
              title: 'NFC Okutun',
              desc:
                  'Etiketleri teker teker cihazınıza okutun. Her başarılı okumada titreşim hissedeceksiniz.',
              icon: Icons.nfc,
            ),
            const SizedBox(height: 10),
            _InstructionCard(
              step: 4,
              title: 'Tamamlayın',
              desc: 'Tüm etiketleri okuttuktan sonra "İşlemi Tamamla"ya basın.',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// Status Card Widget
// ────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final String? barkod;
  final bool nfcActive;
  final int count;
  final String message;
  final bool isLoading;

  const _StatusCard({
    required this.barkod,
    required this.nfcActive,
    required this.count,
    required this.message,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        nfcActive ? DepoTheme.success : DepoTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: statusColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                nfcActive ? Icons.nfc : Icons.qr_code,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nfcActive ? 'NFC Oturumu Aktif' : 'Bekleniyor',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              if (isLoading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
            ],
          ),
          if (barkod != null) ...[
            const SizedBox(height: 12),
            Text('Barkod:',
                style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8), fontSize: 12)),
            Text(
              barkod!,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1.2),
            ),
          ],
          if (nfcActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text('$count NFC eşleştirildi',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
// Instruction Card Widget
// ────────────────────────────────────────────
class _InstructionCard extends StatelessWidget {
  final int step;
  final String title;
  final String desc;
  final IconData icon;

  const _InstructionCard({
    required this.step,
    required this.title,
    required this.desc,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DepoTheme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: DepoTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$step',
                  style: GoogleFonts.inter(
                      color: DepoTheme.primaryColor,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: DepoTheme.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                Text(desc,
                    style: GoogleFonts.inter(
                        color: DepoTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
// Barcode Scanner Full-Screen Page
// ────────────────────────────────────────────
class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _found = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Barkod Tara',
            style: GoogleFonts.inter(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_found) return;
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null) {
                _found = true;
                _controller.stop();
                Navigator.of(context).pop(code);
              }
            },
          ),
          // Overlay
          Center(
            child: Container(
              width: 260,
              height: 140,
              decoration: BoxDecoration(
                border:
                    Border.all(color: DepoTheme.accentColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Barkodu çerçeve içine alın',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
