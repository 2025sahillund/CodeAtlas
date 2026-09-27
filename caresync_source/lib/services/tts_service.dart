import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;
  static bool _isPlaying = false;
  static ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  static Future<void> _init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setSpeechRate(0.42); // Slow, clear cadence for elderly users
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isPlaying = true;
        isPlayingNotifier.value = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        isPlayingNotifier.value = false;
      });

      _flutterTts.setCancelHandler(() {
        _isPlaying = false;
        isPlayingNotifier.value = false;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        _isPlaying = false;
        isPlayingNotifier.value = false;
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint("TTS init warning: $e");
    }
  }

  static Future<void> speak({required String text, required String langCode}) async {
    await _init();
    try {
      if (_isPlaying) {
        await stop();
        return;
      }

      final String language = (langCode == 'hi') ? 'hi-IN' : 'en-IN';
      await _flutterTts.setLanguage(language);
      
      _isPlaying = true;
      isPlayingNotifier.value = true;
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Speak Error: $e");
      _isPlaying = false;
      isPlayingNotifier.value = false;
    }
  }

  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isPlaying = false;
      isPlayingNotifier.value = false;
    } catch (e) {
      debugPrint("TTS Stop Error: $e");
    }
  }
}
