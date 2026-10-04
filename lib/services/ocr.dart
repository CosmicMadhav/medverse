import 'dart:convert';
import 'dart:io';
import '../config/secrets.dart';
import 'groq.dart';

class OcrLine {
  final String text;
  final double confidence; // 0..1, average of word confidences in the row
  const OcrLine(this.text, this.confidence);
}

class OcrResult {
  final List<OcrLine> lines;
  const OcrResult(this.lines);
  bool get isEmpty => lines.isEmpty;
  String get fullText => lines.map((l) => l.text).join('\n');
}

class OcrException implements Exception {
  final String message;
  OcrException(this.message);
  @override
  String toString() => message;
}

/// Google Cloud Vision DOCUMENT_TEXT_DETECTION over REST.
/// Words are regrouped into visual rows using their bounding boxes, so table
/// rows like "Haemoglobin 9.8 g/dL 12.0 - 15.5" stay on one line.
class Ocr {
  static const _endpoint = 'https://vision.googleapis.com/v1/images:annotate';

  static Future<OcrResult> readImages(List<String> paths) async {
    final all = <OcrLine>[];
    for (final p in paths) {
      final r = await readImage(p);
      all.addAll(r.lines);
    }
    return OcrResult(all);
  }

  /// Which engine produced the last result ('google' or 'groq') — shown to the user.
  static String lastEngine = 'google';

  static Future<OcrResult> readImage(String path) async {
    try {
      final r = await _google(path);
      lastEngine = 'google';
      return r;
    } on OcrException catch (e) {
      // Billing off, quota, network blip… fall back to Groq vision.
      try {
        final bytes = await File(path).readAsBytes();
        final text = await Groq.transcribe(base64Encode(bytes), mime: path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
        lastEngine = 'groq';
        final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('```')).toList();
        return OcrResult([for (final l in lines) OcrLine(l, .9)]);
      } catch (_) {
        throw e; // report the original (Google) reason
      }
    }
  }

  static Future<OcrResult> _google(String path) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.length > 9 * 1024 * 1024) {
      throw OcrException('Photo is too large. Try a smaller image.');
    }
    final body = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Encode(bytes)},
          'features': [
            {'type': 'DOCUMENT_TEXT_DETECTION'}
          ],
          'imageContext': {
            'languageHints': ['en', 'hi']
          },
        }
      ]
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(Uri.parse('$_endpoint?key=$visionApiKey'));
      req.headers.contentType = ContentType.json;
      req.write(body);
      final res = await req.close().timeout(const Duration(seconds: 45));
      final text = await res.transform(utf8.decoder).join();
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (res.statusCode != 200) {
        final msg = (json['error']?['message'] ?? 'HTTP ${res.statusCode}').toString();
        if (res.statusCode == 403) {
          throw OcrException('Vision API refused the key. Enable Cloud Vision API and billing for this key. ($msg)');
        }
        throw OcrException('OCR failed: $msg');
      }
      final r = (json['responses'] as List).first as Map<String, dynamic>;
      if (r['error'] != null) throw OcrException('OCR failed: ${r['error']['message']}');
      final full = r['fullTextAnnotation'] as Map<String, dynamic>?;
      if (full == null) return const OcrResult([]);
      return OcrResult(_rows(full));
    } on SocketException {
      throw OcrException('No internet connection. OCR needs internet.');
    } on HandshakeException {
      throw OcrException('Secure connection failed. Check your internet.');
    } finally {
      client.close();
    }
  }

  static List<OcrLine> _rows(Map<String, dynamic> full) {
    final words = <_W>[];
    for (final page in (full['pages'] as List? ?? const [])) {
      for (final block in (page['blocks'] as List? ?? const [])) {
        for (final para in (block['paragraphs'] as List? ?? const [])) {
          for (final w in (para['words'] as List? ?? const [])) {
            final text = (w['symbols'] as List).map((s) => s['text']).join();
            final v = (w['boundingBox']?['vertices'] as List?) ?? const [];
            if (v.length < 4) continue;
            double g(int i, String k) => ((v[i][k] ?? 0) as num).toDouble();
            final top = (g(0, 'y') + g(1, 'y')) / 2;
            final bottom = (g(2, 'y') + g(3, 'y')) / 2;
            final left = (g(0, 'x') + g(3, 'x')) / 2;
            words.add(_W(text, left, (top + bottom) / 2, (bottom - top).abs(),
                ((w['confidence'] ?? 0.9) as num).toDouble()));
          }
        }
      }
    }
    if (words.isEmpty) {
      return full['text'].toString().split('\n').where((l) => l.trim().isNotEmpty).map((l) => OcrLine(l.trim(), .9)).toList();
    }
    words.sort((a, b) => a.y.compareTo(b.y));
    final rows = <List<_W>>[];
    for (final w in words) {
      if (rows.isNotEmpty) {
        final r = rows.last;
        final avgY = r.map((e) => e.y).reduce((a, b) => a + b) / r.length;
        final avgH = r.map((e) => e.h).reduce((a, b) => a + b) / r.length;
        if ((w.y - avgY).abs() <= (avgH < 8 ? 8 : avgH) * .6) {
          r.add(w);
          continue;
        }
      }
      rows.add([w]);
    }
    return [
      for (final r in rows)
        () {
          r.sort((a, b) => a.x.compareTo(b.x));
          final conf = r.map((e) => e.conf).reduce((a, b) => a + b) / r.length;
          return OcrLine(r.map((e) => e.text).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(), conf);
        }()
    ].where((l) => l.text.isNotEmpty).toList();
  }
}

class _W {
  final String text;
  final double x, y, h, conf;
  _W(this.text, this.x, this.y, this.h, this.conf);
}
