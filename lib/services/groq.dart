import 'dart:convert';
import 'dart:io';
import '../config/secrets.dart';

class GroqException implements Exception {
  final String message;
  GroqException(this.message);
  @override
  String toString() => message;
}

/// Thin Groq (OpenAI-compatible) client.
///  • [explain]  – natural everyday Hindi/English, also reads images
///  • [reason]   – stronger reasoning, used for opinion comparison
class Groq {
  static const explain = 'qwen/qwen3.8-27b';
  static const reason = 'openai/gpt-oss-120b';
  static const fast = 'openai/gpt-oss-20b';
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  /// Chat completion that returns parsed JSON. Falls back through [models].
  static Future<Map<String, dynamic>> json({
    required String system,
    required String user,
    List<String> models = const [explain, fast],
    double temperature = 0.2,
    int maxTokens = 2500,
  }) async {
    Object? last;
    for (final m in models) {
      try {
        final body = {
          'model': m,
          'messages': [
            {'role': 'system', 'content': system},
            {'role': 'user', 'content': user},
          ],
          'response_format': {'type': 'json_object'},
          'temperature': temperature,
          'max_tokens': maxTokens,
          if (m.startsWith('openai/')) 'reasoning_effort': 'low',
        };
        final text = await _post(body);
        return _extract(text);
      } catch (e) {
        last = e;
      }
    }
    throw GroqException(last.toString());
  }

  /// Vision: transcribe all text in an image (used as OCR fallback).
  static Future<String> transcribe(String base64Jpeg, {String mime = 'image/jpeg'}) async {
    final body = {
      'model': explain,
      'temperature': 0,
      'max_tokens': 3000,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  'Transcribe ALL text in this medical document image exactly as written, line by line. '
                      'Keep each table row (test name, value, unit, reference range) on ONE line separated by spaces. '
                      'Include Hindi/Devanagari text as-is. Do not add commentary, do not translate, do not summarise.'
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mime;base64,$base64Jpeg'}
            },
          ]
        }
      ],
    };
    return (await _post(body)).trim();
  }

  static Future<String> _post(Map<String, dynamic> body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(Uri.parse(_url));
      req.headers.set('Authorization', 'Bearer $groqApiKey');
      req.headers.set('User-Agent', 'curl/8.4');
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 60));
      final raw = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        String msg = raw;
        try {
          msg = jsonDecode(raw)['error']['message'].toString();
        } catch (_) {}
        throw GroqException('Groq ${res.statusCode}: $msg');
      }
      return (jsonDecode(raw)['choices'][0]['message']['content'] ?? '').toString();
    } on SocketException {
      throw GroqException('No internet connection.');
    } finally {
      client.close();
    }
  }

  /// Models sometimes wrap JSON in fences or prose; pull out the object.
  static Map<String, dynamic> _extract(String text) {
    var t = text.trim();
    t = t.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    final s = t.indexOf('{'), e = t.lastIndexOf('}');
    if (s < 0 || e <= s) throw GroqException('Model returned no JSON.');
    return jsonDecode(t.substring(s, e + 1)) as Map<String, dynamic>;
  }
}
