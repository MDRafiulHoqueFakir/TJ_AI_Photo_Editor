import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Calls the local server's Replicate proxy (see tools/serve.js) so the API
/// token never reaches the browser. Only functional when the app is served by
/// that Node server (run_web.bat) AND a token is configured in
/// `.replicate-token`. Returns null with a reason otherwise.
class GenerativeResult {
  const GenerativeResult({this.image, this.error});
  final Uint8List? image;
  final String? error; // 'no-token', 'failed', or a message
  bool get ok => image != null;
}

abstract class GenerativeService {
  /// Whether the proxy reports a configured token.
  static Future<bool> isConfigured() async {
    try {
      final r = await http.get(Uri.parse('/api/config'));
      if (r.statusCode != 200) return false;
      return (jsonDecode(r.body) as Map)['hasToken'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Save the user's token via the local proxy (browser paste -> file on disk).
  static Future<bool> setToken(String token) async {
    try {
      final r = await http.post(
        Uri.parse('/api/set-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token.trim()}),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Run a Replicate model ("owner/name") with [input]; returns the first
  /// output image. [imageBytes], when given, is sent as a data-URI under the
  /// [imageKey] input field (most image models use "image").
  static Future<GenerativeResult> run(
    String model,
    Map<String, dynamic> input, {
    Uint8List? imageBytes,
    String imageKey = 'image',
  }) async {
    final body = <String, dynamic>{...input};
    if (imageBytes != null) {
      body[imageKey] = 'data:image/png;base64,${base64Encode(imageBytes)}';
    }
    http.Response r;
    try {
      r = await http.post(
        Uri.parse('/api/replicate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'model': model, 'input': body}),
      );
    } catch (e) {
      return GenerativeResult(error: 'Proxy unreachable. Launch via run_web.bat. ($e)');
    }
    if (r.statusCode == 400 && r.body.contains('no-token')) {
      return const GenerativeResult(error: 'no-token');
    }
    if (r.statusCode >= 400) {
      // Surface the real Replicate error (model not found, invalid input,
      // billing required, etc.) instead of a generic message.
      var detail = 'Error ${r.statusCode}';
      try {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        detail = (j['detail'] ?? j['title'] ?? j['error'] ?? detail).toString();
      } catch (_) {}
      return GenerativeResult(error: detail);
    }

    Map<String, dynamic> pred;
    try {
      pred = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      // Not JSON — usually the proxy isn't running (app not launched via
      // run_web.bat) so /api/replicate fell through to the static handler.
      return const GenerativeResult(
        error: 'AI service not reachable. Launch with run_web.bat and set a token.',
      );
    }
    if (pred['status'] == 'failed') {
      return GenerativeResult(error: pred['error']?.toString() ?? 'Generation failed.');
    }
    // The proxy returns the result image inline as a data URI (no CORS fetch).
    final dataUri = pred['image'] as String?;
    if (dataUri == null || !dataUri.contains(',')) {
      return const GenerativeResult(error: 'No output produced.');
    }
    try {
      final bytes = base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));
      return GenerativeResult(image: bytes);
    } catch (_) {
      return const GenerativeResult(error: 'Could not read the result.');
    }
  }
}
