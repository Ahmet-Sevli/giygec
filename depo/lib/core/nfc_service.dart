import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class DepoNfcService {
  static final DepoNfcService _instance = DepoNfcService._();
  factory DepoNfcService() => _instance;
  DepoNfcService._();

  Future<bool> isAvailable() async {
    try {
      final avail = await NfcManager.instance.checkAvailability();
      return avail == NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  /// Tek seferlik NFC okuma — callback geldiğinde oturumu kapatmaz.
  void startContinuousSession({
    required void Function(String uid) onTagRead,
    required void Function(String error) onError,
  }) {
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        try {
          final uid = _extractUid(tag);
          if (uid != null) {
            onTagRead(uid);
          } else {
            onError('NFC etiketi okunamadı');
          }
        } catch (e) {
          onError('NFC okuma hatası: $e');
        }
      },
    );
  }

  void stopSession() {
    NfcManager.instance.stopSession();
  }

  String? _extractUid(NfcTag tag) {
    final androidTag = NfcTagAndroid.from(tag);
    if (androidTag != null) {
      return _bytesToHex(androidTag.id);
    }
    return null;
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }
}
