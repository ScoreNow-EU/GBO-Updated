// Tiny local HTTP server for the Kanban board.
// Run:  dart run planning/kanban_server.dart
//
// Serves planning/kanban_board.json via:
//   GET  http://localhost:8099/kanban   → read the file
//   PUT  http://localhost:8099/kanban   → overwrite the file
//
// The Flutter web app talks to this server so the board data
// lives on disk and never touches Firebase.

import 'dart:convert';
import 'dart:io';

const _port = 8099;
const _jsonPath = 'planning/kanban_board.json';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
  print('Kanban server listening on http://localhost:$_port');
  print('Serving file: $_jsonPath');

  await for (final request in server) {
    // CORS headers so the Flutter web app (different port) can call us
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, PUT, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      continue;
    }

    if (request.uri.path == '/kanban') {
      if (request.method == 'GET') {
        await _handleGet(request);
      } else if (request.method == 'PUT') {
        await _handlePut(request);
      } else {
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..write('Method not allowed')
          ..close();
      }
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found')
        ..close();
    }
  }
}

Future<void> _handleGet(HttpRequest request) async {
  final file = File(_jsonPath);
  if (await file.exists()) {
    final content = await file.readAsString();
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(content)
      ..close();
  } else {
    // Return default empty board
    const defaultBoard = '[]';
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(defaultBoard)
      ..close();
  }
}

Future<void> _handlePut(HttpRequest request) async {
  try {
    final body = await utf8.decoder.bind(request).join();
    // Validate it's proper JSON
    final parsed = jsonDecode(body);
    // Pretty-print before saving
    final pretty = const JsonEncoder.withIndent('  ').convert(parsed);

    final file = File(_jsonPath);
    await file.writeAsString(pretty);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{"status":"saved"}')
      ..close();

    print('[${DateTime.now().toIso8601String()}] Board saved (${pretty.length} bytes)');
  } catch (e) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('Invalid JSON: $e')
      ..close();
  }
}
