import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api_service.dart';
import '../core/nfc_service.dart';
import '../core/theme.dart';

/// Stok Kontrol Ekranı
/// NFC okutarak veya barkod tarayarak ürün stok bilgisi görüntüler.
class StokKontrolScreen extends StatefulWidget {
  const StokKontrolScreen({super.key});

  @override
  State<StokKontrolScreen> createState() => _StokKontrolScreenState();
}

class _StokKontrolScreenState extends State<StokKontrolScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DepoNfcService _nfcService = DepoNfcService();

  bool _nfcListening = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _stokData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_nfcListening) {
        _nfcService.stopSession();
        setState(() => _nfcListening = false);
      }
    });
  }

  @override
  void dispose() {
    if (_nfcListening) _nfcService.stopSession();
    _tabController.dispose();
    super.dispose();
  }

  // ── NFC ile Stok Sorgula ──
  void _startNfcStok() {
    setState(() {
      _nfcListening = true;
      _stokData = null;
      _error = null;
    });

    _nfcService.startContinuousSession(
      onTagRead: (uid) async {
        _nfcService.stopSession();
        setState(() {
          _nfcListening = false;
          _isLoading = true;
        });
        try {
          final res = await DepoApiService.stokNfc(uid);
          setState(() {
            _stokData = res;
            _error = null;
          });
        } catch (e) {
          setState(() => _error = 'Sunucu hatası: $e');
        } finally {
          setState(() => _isLoading = false);
        }
      },
      onError: (e) {
        setState(() {
          _nfcListening = false;
          _error = e;
        });
      },
    );
  }

  // ── Barkod ile Stok Sorgula ──
  Future<void> _startBarkodStok() async {
    final barkod = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarkodScannerPage()),
    );
    if (barkod == null || barkod.isEmpty) return;

    // Barkod DB doğrulaması
    setState(() {
      _isLoading = true;
      _stokData = null;
      _error = null;
    });
    final gecerli = await DepoApiService.barkodDogrula(barkod);
    if (!gecerli) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Geçersiz barkod! Lütfen sistemimizde kayıtlı bir ürün barkodu okutun.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      final res = await DepoApiService.stokBarkod(barkod);
      setState(() {
        _stokData = res;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Sunucu hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DepoTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Stok Kontrol',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Divider(height: 1, color: DepoTheme.dividerColor),
              TabBar(
                controller: _tabController,
                labelColor: DepoTheme.primaryColor,
                unselectedLabelColor: DepoTheme.textSecondary,
                indicatorColor: DepoTheme.primaryColor,
                tabs: const [
                  Tab(icon: Icon(Icons.nfc), text: 'NFC ile'),
                  Tab(icon: Icon(Icons.qr_code_scanner), text: 'Barkod ile'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── NFC Tab ──
          _buildNfcTab(),
          // ── Barkod Tab ──
          _buildBarkodTab(),
        ],
      ),
    );
  }

  Widget _buildNfcTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Okuma kartı
          _NfcScanCard(
            listening: _nfcListening,
            onStart: _startNfcStok,
            onStop: () {
              _nfcService.stopSession();
              setState(() => _nfcListening = false);
            },
          ),
          const SizedBox(height: 16),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_error != null) _ErrorWidget(message: _error!),
          if (_stokData != null) _StokResultWidget(data: _stokData!),
        ],
      ),
    );
  }

  Widget _buildBarkodTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.qr_code_scanner,
                    color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text('Barkod Tara',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 6),
                Text('Ürün barkodunu kameraya gösterin.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.8), fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _startBarkodStok,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Barkod Tara'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_error != null) _ErrorWidget(message: _error!),
          if (_stokData != null) _StokResultWidget(data: _stokData!),
        ],
      ),
    );
  }
}

// ── NFC Scan Card ──
class _NfcScanCard extends StatelessWidget {
  final bool listening;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _NfcScanCard(
      {required this.listening, required this.onStart, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: listening
              ? [const Color(0xFF0EA5E9), const Color(0xFF2563EB)]
              : [const Color(0xFF1E293B), const Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(listening ? Icons.nfc : Icons.nfc_outlined,
              color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            listening ? 'NFC Etiketini Okutun...' : 'NFC ile Stok Sorgula',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (listening)
            ElevatedButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop),
              label: const Text('İptal'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2563EB)),
            )
          else
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.nfc),
              label: const Text('NFC Oku'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B)),
            ),
        ],
      ),
    );
  }
}

// ── Stok Sonuç Widgetı ──
class _StokResultWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const _StokResultWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    final urun = data['urun'] as Map<String, dynamic>?;
    final secili = data['secili_barkod'] as Map<String, dynamic>?;
    final tumleri =
        (data['tum_beden_stoklari'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ana ürün kartı
        if (urun != null)
          _UrunBilgiCard(urun: urun, secili: secili),
        const SizedBox(height: 16),

        // Beden stok tablosu
        if (tumleri.isNotEmpty)
          _BedenStokTable(barkodlar: tumleri, seciliBarkodId: secili?['barkod_id'] ?? ''),
      ],
    );
  }
}

class _UrunBilgiCard extends StatelessWidget {
  final Map<String, dynamic> urun;
  final Map<String, dynamic>? secili;

  const _UrunBilgiCard({required this.urun, required this.secili});

  @override
  Widget build(BuildContext context) {
    final imageUrl = urun['imageUrl'] ?? urun['image'] ?? '';
    final name = urun['name'] ?? urun['title'] ?? 'Ürün';
    final price = urun['price'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
              child: Image.network(imageUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: DepoTheme.scaffoldBg,
                        child: const Icon(Icons.image_not_supported,
                            color: DepoTheme.textSecondary),
                      )),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (price != '')
                    Text('₺$price',
                        style: GoogleFonts.inter(
                            color: DepoTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  if (secili != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if ((secili!['renk'] ?? '').toString().isNotEmpty)
                          _Chip(label: secili!['renk']),
                        if ((secili!['size'] ?? '').toString().isNotEmpty)
                          _Chip(label: 'Beden ${secili!['size']}'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BedenStokTable extends StatelessWidget {
  final List<Map<String, dynamic>> barkodlar;
  final String seciliBarkodId;

  const _BedenStokTable(
      {required this.barkodlar, required this.seciliBarkodId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DepoTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Beden Stok Durumu',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: DepoTheme.textPrimary)),
          ),
          Divider(height: 1, color: DepoTheme.dividerColor),
          ...barkodlar.map((b) {
            final stok = (b['stok'] ?? 0) as int;
            final isSelected = b['barkod_id'] == seciliBarkodId;
            return Container(
              color: isSelected
                  ? DepoTheme.primaryColor.withOpacity(0.05)
                  : null,
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: stok > 0
                      ? DepoTheme.success.withOpacity(0.15)
                      : DepoTheme.error.withOpacity(0.15),
                  child: Text(
                    b['size']?.toString() ?? '-',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: stok > 0 ? DepoTheme.success : DepoTheme.error),
                  ),
                ),
                title: Text('Beden ${b['size'] ?? '-'}',
                    style: GoogleFonts.inter(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal)),
                subtitle: Text(b['renk'] ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: DepoTheme.textSecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.arrow_right,
                            color: DepoTheme.primaryColor, size: 18),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: stok > 0
                            ? DepoTheme.success.withOpacity(0.1)
                            : DepoTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$stok adet',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: stok > 0
                                ? DepoTheme.success
                                : DepoTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: DepoTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              color: DepoTheme.primaryColor,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  const _ErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DepoTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: DepoTheme.error),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: GoogleFonts.inter(color: DepoTheme.error))),
        ],
      ),
    );
  }
}

// ── Barkod Scanner Page ──
class _BarkodScannerPage extends StatefulWidget {
  const _BarkodScannerPage();

  @override
  State<_BarkodScannerPage> createState() => _BarkodScannerPageState();
}

class _BarkodScannerPageState extends State<_BarkodScannerPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _found = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Barkod Tara', style: GoogleFonts.inter(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: (cap) {
              if (_found) return;
              final code = cap.barcodes.firstOrNull?.rawValue;
              if (code != null) {
                _found = true;
                _ctrl.stop();
                Navigator.of(context).pop(code);
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: DepoTheme.accentColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text('Barkodu çerçeve içine alın',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
