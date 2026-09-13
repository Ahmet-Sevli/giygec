import 'dart:io';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcService {
  /// Check if NFC is available on this device
  Future<bool> isNfcAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (e) {
      return false;
    }
  }

  /// Start an NFC session and return the tag's serial number (UID)
  /// The [onTagRead] callback receives the hex UID string
  void startSession({
    required Function(String uid) onTagRead,
    required Function(String error) onError,
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

  /// Stop the current NFC session
  void stopSession() {
    NfcManager.instance.stopSession();
  }

  /// Extract UID from NFC tag using platform-specific typed accessors (nfc_manager 4.x)
  String? _extractUid(NfcTag tag) {
    // Android: get UID from NfcTagAndroid
    final androidTag = NfcTagAndroid.from(tag);
    if (androidTag != null) {
      return _bytesToHex(androidTag.id);
    }

    return null;
  }

  /// Convert bytes to hex string (uppercase, colon-separated — matches Firestore doc IDs)
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }
}
