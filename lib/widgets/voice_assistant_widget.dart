import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';

class VoiceAssistantController {
  Future<void> Function(String text)? speak;
  Future<void> Function()? stop;
}

class VoiceAssistantWidget extends StatefulWidget {
  final Function(String text) onResult;
  final VoiceAssistantController? controller;

  const VoiceAssistantWidget({
    super.key,
    required this.onResult,
    this.controller,
  });

  @override
  State<VoiceAssistantWidget> createState() => _VoiceAssistantWidgetState();
}

class _VoiceAssistantWidgetState extends State<VoiceAssistantWidget> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  // TTS is nullable and created lazily — never in initState.
  // If two VoiceAssistantWidgets are alive simultaneously (IndexedStack),
  // eagerly calling FlutterTts.setEngine() on both causes:
  //   "Reply already submitted" → FATAL EXCEPTION crash.
  FlutterTts? _tts;
  bool _ttsReady = false;
  bool _isListening = false;
  String _targetLang = "tr-TR";

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      widget.controller!.speak = (text) async {
        await _ensureTts();
        if (!mounted || _tts == null) return;
        await _tts!.speak(text);
      };
      widget.controller!.stop = () async {
        await _tts?.stop();
      };
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts?.stop();
    super.dispose();
  }

  /// Lazily create and configure the TTS engine the first time it is needed.
  Future<void> _ensureTts() async {
    if (_ttsReady) return;
    _ttsReady = true;

    final tts = FlutterTts();
    _tts = tts;

    if (Platform.isAndroid) {
      await tts.setEngine("com.google.android.tts");
    }

    await tts.awaitSpeakCompletion(true);

    // Detect available Turkish locale
    dynamic languages = await tts.getLanguages;
    String target = "tr-TR";
    if (languages is List) {
      for (var lang in languages) {
        final l = lang.toString().toLowerCase();
        if (l == "tr-tr" || l == "tr_tr" || l == "tur-tur" || l == "tr") {
          target = lang.toString();
          break;
        }
      }
    }
    _targetLang = target;

    await tts.setLanguage(_targetLang);
    await tts.setPitch(1.0);
    await tts.setSpeechRate(0.5);
  }

  Future<void> _listen() async {
    if (_isListening) {
      _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    // Mic permission
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (status.isDenied) {
        _showFeedback('Mikrofon izni gerekli.');
        return;
      }
    }

    try {
      final available = await _speech.initialize(
        onStatus: (val) {
          if (!mounted) return;
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _showFeedback('Ses tanıma hatası: ${val.errorMsg}');
        },
      );

      if (!available) {
        _showFeedback('Sesli özellik bu cihazda kullanılamıyor.');
        return;
      }

      if (mounted) setState(() => _isListening = true);

      _speech.listen(
        onResult: (val) {
          if (!mounted) return;
          if (val.finalResult) {
            setState(() => _isListening = false);
            widget.onResult(val.recognizedWords);
          }
        },
        localeId: 'tr_TR',
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      _showFeedback('Başlatma hatası: $e');
    }
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _listen,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _isListening ? AppTheme.accentGradient : AppTheme.primaryGradient,
          boxShadow: _isListening ? AppTheme.glowShadow : null,
        ),
        child: Icon(
          _isListening ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
