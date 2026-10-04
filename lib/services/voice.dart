import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Text-to-speech (EN/HI) and speech-to-text, shared app-wide.
class Voice {
  Voice._();
  static final Voice instance = Voice._();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _ttsReady = false;
  bool _sttReady = false;

  /// Id of whatever is currently being read aloud (null when silent).
  final ValueNotifier<String?> speaking = ValueNotifier(null);
  final ValueNotifier<bool> listening = ValueNotifier(false);

  Future<void> _initTts() async {
    if (_ttsReady) return;
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);
    _tts.setCompletionHandler(() => speaking.value = null);
    _tts.setCancelHandler(() => speaking.value = null);
    _tts.setErrorHandler((_) => speaking.value = null);
    _ttsReady = true;
  }

  Future<void> speak(String id, String text, {required bool hindi}) async {
    await _initTts();
    if (speaking.value == id) {
      await stop();
      return;
    }
    await _tts.stop();
    await _tts.setLanguage(hindi ? 'hi-IN' : 'en-IN');
    speaking.value = id;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    speaking.value = null;
  }

  /// Starts listening. Returns false if the mic/recognizer is unavailable.
  Future<bool> listen({
    required bool hindi,
    required void Function(String text, bool done) onResult,
  }) async {
    if (!_sttReady) {
      _sttReady = await _stt.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') listening.value = false;
        },
        onError: (_) => listening.value = false,
      );
    }
    if (!_sttReady) return false;
    await stop();
    listening.value = true;
    await _stt.listen(
      localeId: hindi ? 'hi_IN' : 'en_IN',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
    );
    return true;
  }

  Future<void> stopListening() async {
    await _stt.stop();
    listening.value = false;
  }
}
