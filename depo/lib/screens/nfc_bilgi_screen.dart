import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api_service.dart';
import '../core/nfc_service.dart';
import '../core/theme.dart';

/// NFC okutarak ürün bilgilerini gösteren ekran.
/// Ayrıca "Yeniden Eşleştir" butonu ile barkod değiştirme imkânı sunar.
class NfcBilgiScreen extends StatefulWidget {
  const NfcBilgiScreen({super.key});

  @override
  State<NfcBilgiScreen> createState() => _NfcBilgiScreenState();
}

class _NfcBilgiScreenState extends State<NfcBilgiScreen> {
  final DepoNfcService _nfcService = DepoNfcService();

  bool _nfcListening = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _nfcData;   // products/{uid}
  Map<String, dynamic>? _barkodData; // barcodes/{barkod}
  Map<String, dynamic>? _urunData;   // catalog product
  String? _currentUid;

  @override
  void dispose() {
    if (_nfcListening) _nfcService.stopSession();
    super.dispose();
  }

  void _startNfcListen() {
    setState(() {
      _nfcListening = true;
      _nfcData = null;
      _barkodData = null;
      _urunData = null;
      _error = null;
      _currentUid = null;
    });

    _nfcService.startContinuousSession(
      onTagRead: (uid) async {
        _nfcService.stopSession();
        setState(() {
          _nfcListening = false;
          _isLoading = true;
          _currentUid = uid;
        });
        try {
          final res = await DepoApiService.nfcBilgi(uid);
          if (res['status'] == 'ok') {
            setState(() {
              _nfcData = res['nfc'] as Map<String, dynamic>?;
              _barkodData = res['barkod_detay'] as Map<String, dynamic>?;
              _urunData = res['urun'] as Map<String, dynamic>?;
              _error = null;
            });
          } else {
            setState(() => _error = res['detail'] ?? 'Hata oluştu');
          }
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

  void _stopListen() {
    _nfcService.stopSession();
    setState(() => _nfcListening = false);
  }

  // ── NFC Güncelle (eski adı: Yeniden Eşleştir) ──
  Future<void> _yenidenEsle() async {
    if (_currentUid == null) return;
    final barkod = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScanForReeMatch()),
    );
    if (barkod == null || barkod.isEmpty) return;

    // Barkod DB doğrulaması
    setState(() => _isLoading = true);
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
      final res = await DepoApiService.nfcYenidenEsle(
          uid: _currentUid!, barkod: barkod);
      if (res['status'] == 'ok') {
        // Refresh info
        final info = await DepoApiService.nfcBilgi(_currentUid!);
        setState(() {
          _nfcData = info['nfc'] as Map<String, dynamic>?;
          _barkodData = info['barkod_detay'] as Map<String, dynamic>?;
          _urunData = info['urun'] as Map<String, dynamic>?;
          _error = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('NFC güncellendi ✓'),
              backgroundColor: DepoTheme.success,
            ),
          );
        }
      } else {
        setState(() => _error = res['detail'] ?? 'Hata');
      }
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
        title: Text('NFC Bilgi Görüntüle',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: DepoTheme.dividerColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── NFC Okuma Kartı ──
                  _NfcReadCard(
                    listening: _nfcListening,
                    hasData: _nfcData != null,
                    uid: _currentUid,
                    onStart: _startNfcListen,
                    onStop: _stopListen,
                  ),
                  const SizedBox(height: 16),

                  // ── Hata ──
                  if (_error != null)
                    _ErrorCard(message: _error!),

                  // ── Ürün Bilgileri ──
                  if (_urunData != null) ...[
                    _UrunKarti(urun: _urunData!, barkodData: _barkodData),
                    const SizedBox(height: 16),
                  ],

                  // ── NFC İçeriği ──
                  if (_nfcData != null) ...[
                    _NfcDetailCard(nfc: _nfcData!),
                    const SizedBox(height: 16),
                  ],

                  // ── Barkod Detayı ──
                  if (_barkodData != null) ...[
                    _BarkodDetailCard(barkod: _barkodData!),
                    const SizedBox(height: 20),
                  ],

                  // ── NFC Güncelle Butonu ──
                  if (_currentUid != null)
                    OutlinedButton.icon(
                      onPressed: _yenidenEsle,
                      icon: const Icon(Icons.system_update_alt_rounded),
                      label: Text('NFC Güncelle',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DepoTheme.primaryColor,
                        side: const BorderSide(color: DepoTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Widgets ──

class _NfcReadCard extends StatelessWidget {
  final bool listening;
  final bool hasData;
  final String? uid;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _NfcReadCard({
    required this.listening,
    required this.hasData,
    required this.uid,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: listening
              ? [const Color(0xFF0EA5E9), const Color(0xFF2563EB)]
              : [const Color(0xFF1E293B), const Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Icon(
            listening ? Icons.nfc : Icons.nfc_outlined,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            listening
                ? 'NFC Etiketini Okutun...'
                : hasData
                    ? 'UID: ${uid ?? ""}'
                    : 'NFC Bilgisi Görüntüle',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          if (!listening && !hasData) ...[
            const SizedBox(height: 6),
            Text(
              'Bir NFC etiketini okutun, ürün bilgileri gösterilecektir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.8), fontSize: 13),
            ),
          ],
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
              label: Text(hasData ? 'Yeni NFC Okut' : 'NFC Okumayı Başlat'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B)),
            ),
        ],
      ),
    );
  }
}

class _UrunKarti extends StatelessWidget {
  final Map<String, dynamic> urun;
  final Map<String, dynamic>? barkodData;

  const _UrunKarti({required this.urun, required this.barkodData});

  @override
  Widget build(BuildContext context) {
    final imageUrl = urun['imageUrl'] ?? urun['image'] ?? '';
    final name = urun['name'] ?? urun['title'] ?? 'Ürün';
    final price = urun['price'] ?? urun['fiyat'] ?? '';
    final amzId = urun['amz_id'] ?? barkodData?['amz_id'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: DepoTheme.scaffoldBg,
                  child: const Center(
                      child: Icon(Icons.image_not_supported,
                          color: DepoTheme.textSecondary)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 6),
                if (price != '')
                  Text('₺$price',
                      style: GoogleFonts.inter(
                          color: DepoTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                if (amzId != '') ...[
                  const SizedBox(height: 4),
                  Text('AMZ ID: $amzId',
                      style: GoogleFonts.inter(
                          color: DepoTheme.textSecondary, fontSize: 12)),
                ],
                if (barkodData != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if ((barkodData!['size'] ?? '').toString().isNotEmpty)
                        _Chip(
                            label:
                                'Beden: ${barkodData!['size']}'),
                      if ((barkodData!['renk'] ?? '').toString().isNotEmpty)
                        _Chip(
                            label: 'Renk: ${barkodData!['renk']}'),
                      _Chip(
                          label: 'Stok: ${barkodData!['stok'] ?? 0}',
                          color: (barkodData!['stok'] ?? 0) > 0
                              ? DepoTheme.success
                              : DepoTheme.error),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcDetailCard extends StatelessWidget {
  final Map<String, dynamic> nfc;

  const _NfcDetailCard({required this.nfc});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'NFC Etiketi Bilgileri',
      icon: Icons.nfc,
      color: DepoTheme.primaryColor,
      rows: [
        _Row('UID', nfc['uid'] ?? '-'),
        _Row('Barkod', nfc['barkod'] ?? '-'),
        _Row('Ödeme', nfc['isPaid'] == true ? 'Evet' : 'Hayır'),
        _Row('Kullanım Sayısı', '${nfc['kullanim_sayisi'] ?? 0}'),
        _Row('Son İşlem', _formatDate(nfc['son_islem'])),
      ],
    );
  }
}

class _BarkodDetailCard extends StatelessWidget {
  final Map<String, dynamic> barkod;

  const _BarkodDetailCard({required this.barkod});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Barkod Bilgileri',
      icon: Icons.qr_code,
      color: DepoTheme.accentColor,
      rows: [
        _Row('AMZ ID', barkod['amz_id'] ?? '-'),
        _Row('Kategori', barkod['category'] ?? '-'),
        _Row('Renk', barkod['renk'] ?? '-'),
        _Row('Beden', barkod['size']?.toString() ?? '-'),
        _Row('Stok', barkod['stok']?.toString() ?? '0'),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_Row> rows;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
          ...rows.map((r) => _buildRow(r)),
        ],
      ),
    );
  }

  Widget _buildRow(_Row r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(r.label,
                style: GoogleFonts.inter(
                    color: DepoTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(r.value,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, this.color = DepoTheme.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: DepoTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DepoTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: DepoTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: GoogleFonts.inter(color: DepoTheme.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

String _formatDate(dynamic raw) {
  if (raw == null) return '-';
  final s = raw.toString();
  if (s.isEmpty) return '-';
  try {
    final dt = DateTime.parse(s).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return s;
  }
}

// ── Barcode scanner for re-match ──
class _BarcodeScanForReeMatch extends StatefulWidget {
  const _BarcodeScanForReeMatch();

  @override
  State<_BarcodeScanForReeMatch> createState() =>
      _BarcodeScanForReeMatchState();
}

class _BarcodeScanForReeMatchState extends State<_BarcodeScanForReeMatch> {
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
        title: Text('Yeni Barkod Tara',
            style: GoogleFonts.inter(color: Colors.white)),
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
        ],
      ),
    );
  }
}
