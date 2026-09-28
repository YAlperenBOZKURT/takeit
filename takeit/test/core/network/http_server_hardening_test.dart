// Real AppHttpServer on loopback: request-level protections every handler
// relies on.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:takeit/core/network/http_server.dart';
import 'package:takeit/core/network/request_body.dart';
import 'package:takeit/core/network/request_origin.dart';

void main() {
  late AppHttpServer server;
  late int port;

  setUp(() async {
    server = AppHttpServer(port: 0);
    // Echo the caller's IP as the server sees it.
    server.registerHandler(
      '/api/takeit/v1/ping',
      (request) async => shelf.Response.ok(remoteIpOf(request) ?? ''),
    );
    // Echo a parsed JSON body.
    server.registerHandler(
      '/api/takeit/v1/message',
      (request) async =>
          shelf.Response.ok(jsonEncode(await readJsonBody(request))),
    );
    await server.start();
    port = server.boundPort!;
  });

  tearDown(() => server.stop());

  /// Status code and body; status is null when the server cut the
  /// connection while the body was still being sent — how an oversized body
  /// is refused once the server stops reading it.
  Future<(int?, String)> send(
    String method,
    String path, {
    Map<String, String> headers = const {},
    List<int>? body,
    bool chunked = false,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:$port/api/takeit/v1$path'),
      );
      headers.forEach(req.headers.set);
      if (body != null) {
        if (chunked) {
          req.headers.chunkedTransferEncoding = true;
        } else {
          req.contentLength = body.length;
        }
        req.add(body);
      }
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      return (res.statusCode, text);
    } on IOException {
      return (null, '');
    } finally {
      client.close(force: true);
    }
  }

  test('a client-supplied X-Real-IP is ignored', () async {
    final (status, ip) = await send(
      'GET',
      '/ping',
      headers: {'X-Real-IP': '10.9.9.9'},
    );
    expect(status, 200);
    expect(ip, '127.0.0.1');
  });

  test('a normal JSON body is parsed', () async {
    final (status, text) = await send(
      'POST',
      '/message',
      body: utf8.encode(jsonEncode({'content': 'hi'})),
    );
    expect(status, 200);
    expect(jsonDecode(text), {'content': 'hi'});
  });

  test('an oversized JSON body is refused with 413', () async {
    final (status, _) = await send(
      'POST',
      '/message',
      body: List.filled(kMaxJsonBodyBytes + 1, 0x20),
    );
    expect(status, 413);
  });

  test(
    'an oversized chunked body (no Content-Length) is refused too',
    () async {
      final (status, _) = await send(
        'POST',
        '/message',
        body: List.filled(kMaxJsonBodyBytes + 1, 0x20),
        chunked: true,
      );
      // Refused either way: a 413 or the connection cut mid-body.
      expect(status, anyOf(413, isNull));
    },
  );

  test('malformed JSON is a 400, not a 500', () async {
    final (status, _) = await send(
      'POST',
      '/message',
      body: utf8.encode('{"content": '),
    );
    expect(status, 400);
  });
}
