import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

/// İşlem Logları Ekranı
/// Sunucudan log kayıtlarını çeker, türe göre filtreleme imkânı sunar.
class LoglarScreen extends StatefulWidget {
  const LoglarScreen({super.key});

  @override
  State<LoglarScreen> createState() => _LoglarScreenState();
}

class _LoglarScreenState extends State<LoglarScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  String? _error;
  String _selectedType = 'all';

  static const List<Map<String, String>> _logTypes = [
    {'value': 'all', 'label': 'Tümü', 'icon': '📋'},
    {'value': 'barcode_match', 'label': 'Barkod Eşleştirme', 'icon': '🔗'},
    {'value': 'nfc_register', 'label': 'NFC Kayıt', 'icon': '📡'},
    {'value': 'nfc_guncelle', 'label': 'NFC Güncelleme', 'icon': '🔄'},
    {'value': 'purchase', 'label': 'Satın Alma', 'icon': '🛒'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await DepoApiService.getLogs(
        logType: _selectedType == 'all' ? null : _selectedType,
        limit: 100,
      );
      setState(() {
        _logs = (res['logs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
        title: Text('İşlem Logları',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: DepoTheme.dividerColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filtre Sekmesi ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _logTypes.map((t) {
                  final isSelected = _selectedType == t['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${t['icon']} ${t['label']}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : DepoTheme.textPrimary)),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedType = t['value']!);
                        _fetchLogs();
                      },
                      selectedColor: DepoTheme.primaryColor,
                      checkmarkColor: Colors.white,
                      backgroundColor: DepoTheme.scaffoldBg,
                      side: BorderSide(
                          color: isSelected
                              ? DepoTheme.primaryColor
                              : DepoTheme.dividerColor),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Divider(height: 1, color: DepoTheme.dividerColor),

          // ── İçerik ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorCenter(message: _error!)
                    : _logs.isEmpty
                        ? _EmptyState()
                        : _LogListView(logs: _logs),
          ),
        ],
      ),
    );
  }
}

class _LogListView extends StatelessWidget {
  final List<Map<String, dynamic>> logs;

  const _LogListView({required this.logs});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LogCard(log: logs[i]),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _LogCard({required this.log});

  static const Map<String, Map<String, dynamic>> _typeStyles = {
    'barcode_match': {
      'color': Color(0xFF2563EB),
      'bg': Color(0xFFEFF6FF),
      'icon': Icons.link,
      'label': 'Barkod Eşleştirme',
    },
    'nfc_register': {
      'color': Color(0xFF059669),
      'bg': Color(0xFFECFDF5),
      'icon': Icons.nfc,
      'label': 'NFC Kayıt',
    },
    'nfc_guncelle': {
      'color': Color(0xFF0284C7),
      'bg': Color(0xFFE0F2FE),
      'icon': Icons.system_update_alt_rounded,
      'label': 'NFC Güncelleme',
    },

    'purchase': {
      'color': Color(0xFF7C3AED),
      'bg': Color(0xFFF5F3FF),
      'icon': Icons.shopping_cart,
      'label': 'Satın Alma',
    },
  };

  @override
  Widget build(BuildContext context) {
    final type = log['type'] as String? ?? 'unknown';
    final style = _typeStyles[type] ??
        {
          'color': DepoTheme.textSecondary,
          'bg': DepoTheme.scaffoldBg,
          'icon': Icons.info_outline,
          'label': type,
        };

    final color = style['color'] as Color;
    final bg = style['bg'] as Color;
    final icon = style['icon'] as IconData;
    final label = style['label'] as String;
    final message = log['message'] as String? ?? '';
    final timestamp = log['timestamp'] as String? ?? '';
    final details = log['details'] as Map<String, dynamic>? ?? {};

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: GoogleFonts.inter(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const Spacer(),
                Text(_formatTs(timestamp),
                    style: GoogleFonts.inter(
                        color: DepoTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: DepoTheme.textPrimary)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...details.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Text('${e.key}: ',
                                style: GoogleFonts.inter(
                                    color: DepoTheme.textSecondary,
                                    fontSize: 11)),
                            Expanded(
                              child: Text('${e.value}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: DepoTheme.textPrimary)),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTs(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

class _ErrorCenter extends StatelessWidget {
  final String message;
  const _ErrorCenter({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: DepoTheme.error, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: DepoTheme.error)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, color: DepoTheme.textSecondary, size: 64),
          const SizedBox(height: 16),
          Text('Log kaydı bulunamadı',
              style: GoogleFonts.inter(
                  color: DepoTheme.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}
