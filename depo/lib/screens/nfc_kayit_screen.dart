import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_service.dart';
import '../core/nfc_service.dart';
import '../core/theme.dart';

/// NFC Kayıt Ekranı
/// "Kaydetmeye Başla" butonuna basınca sürekli NFC okur,
/// yeni UID'leri sisteme kaydeder, her başarılı okumada bip sesi çıkarır.
/// Aynı UID'yi kısa sürede tekrar okuma koruması vardır.
class NfcKayitScreen extends StatefulWidget {
  const NfcKayitScreen({super.key});

  @override
  State<NfcKayitScreen> createState() => _NfcKayitScreenState();
}

class _NfcKayitScreenState extends State<NfcKayitScreen> {
  final DepoNfcService _nfcService = DepoNfcService();

  bool _active = false;
  bool _isLoading = false;

  // Debounce — aynı UID'yi tekrar okumamak için
  final Set<String> _recentUids = {};
  final Map<String, DateTime> _lastSeen = {};
  static const _debounceMs = 2000; // 2 saniye

  // Kayıt durumları
  final List<_NfcEntry> _entries = [];
  int _newCount = 0;
  int _existingCount = 0;

  @override
  void dispose() {
    if (_active) _nfcService.stopSession();
    super.dispose();
  }

  Future<void> _playBeep() async {
    try {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void _startReading() {
    setState(() {
      _active = true;
      _entries.clear();
      _newCount = 0;
      _existingCount = 0;
      _recentUids.clear();
      _lastSeen.clear();
    });

    _nfcService.startContinuousSession(
      onTagRead: (uid) async {
        // Debounce check
        final now = DateTime.now();
        final lastSeen = _lastSeen[uid];
        if (lastSeen != null &&
            now.difference(lastSeen).inMilliseconds < _debounceMs) {
          return; // Bu UID çok yakın zamanda okundu, atla
        }
        _lastSeen[uid] = now;

        setState(() => _isLoading = true);
        try {
          final res = await DepoApiService.nfcKayit(uid);
          final status = res['status'] as String? ?? '';
          final isNew = status == 'ok';

          setState(() {
            _entries.insert(
              0,
              _NfcEntry(
                uid: uid,
                isNew: isNew,
                timestamp: now,
                message: isNew ? 'Kaydedildi' : 'Zaten kayıtlı',
              ),
            );
            if (isNew) {
              _newCount++;
            } else {
              _existingCount++;
            }
          });

          if (isNew) {
            await _playBeep();
          }
        } catch (e) {
          setState(() {
            _entries.insert(
              0,
              _NfcEntry(
                uid: uid,
                isNew: false,
                timestamp: now,
                message: 'Hata: $e',
                isError: true,
              ),
            );
          });
        } finally {
          setState(() => _isLoading = false);
        }
      },
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('NFC Hata: $err'),
                backgroundColor: DepoTheme.error),
          );
        }
      },
    );
  }

  void _stopReading() {
    _nfcService.stopSession();
    setState(() => _active = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DepoTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('NFC Kayıt',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: DepoTheme.dividerColor),
        ),
      ),
      body: Column(
        children: [
          // ── Kontrol Paneli ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _active
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [const Color(0xFF1E293B), const Color(0xFF334155)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _active ? Icons.sensors : Icons.sensors_off,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _active ? 'NFC Okuma Aktif' : 'NFC Kapalı',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Text(
                            _active
                                ? 'Etiketleri cihazınıza okutun'
                                : '"Kaydetmeye Başla" ile başlayın',
                            style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                  ],
                ),

                if (_entries.isNotEmpty || _active) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatBubble(
                          count: _newCount,
                          label: 'Yeni',
                          color: DepoTheme.success),
                      _StatBubble(
                          count: _existingCount,
                          label: 'Mevcut',
                          color: DepoTheme.accentColor),
                      _StatBubble(
                          count: _entries.length,
                          label: 'Toplam',
                          color: Colors.white70),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                if (!_active)
                  ElevatedButton.icon(
                    onPressed: _startReading,
                    icon: const Icon(Icons.play_arrow),
                    label: Text('Kaydetmeye Başla',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF059669),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _stopReading,
                    icon: const Icon(Icons.stop),
                    label: Text('Durdur',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: DepoTheme.error,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ),

          // ── Kayıt Listesi ──
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.nfc,
                            size: 64, color: DepoTheme.textSecondary.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          _active
                              ? 'Henüz NFC okutulmadı'
                              : 'Kayıt başlatılmadı',
                          style: GoogleFonts.inter(
                              color: DepoTheme.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _EntryCard(entry: _entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Entry Model ──
class _NfcEntry {
  final String uid;
  final bool isNew;
  final bool isError;
  final DateTime timestamp;
  final String message;

  _NfcEntry({
    required this.uid,
    required this.isNew,
    required this.timestamp,
    required this.message,
    this.isError = false,
  });
}

// ── Entry Card ──
class _EntryCard extends StatelessWidget {
  final _NfcEntry entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = entry.isError
        ? DepoTheme.error
        : entry.isNew
            ? DepoTheme.success
            : DepoTheme.accentColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              entry.isError
                  ? Icons.error_outline
                  : entry.isNew
                      ? Icons.check_circle
                      : Icons.info_outline,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.uid,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
                Text(
                  entry.message,
                  style: GoogleFonts.inter(
                      color: color, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Text(
            '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(
                color: DepoTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Stat Bubble ──
class _StatBubble extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatBubble(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 24)),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ],
    );
  }
}
