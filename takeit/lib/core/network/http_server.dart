import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../constants/network_constants.dart';

typedef RequestHandler = Future<shelf.Response> Function(shelf.Request request);

class AppHttpServer {
  HttpServer? _server;
  final int port;
  final Router _router = Router();
  final Map<String, RequestHandler> _handlers = {};

  // ─── Rate limiter state ───
  // Per-IP request counts, reset every _rateLimitWindow.
  final Map<String, int> _requestCounts = {};
  DateTime _windowStart = DateTime.now();
  static const int _maxRequestsPerWindow = 100;
  static const Duration _rateLimitWindow = Duration(seconds: 10);

  AppHttpServer({this.port = kDefaultPort}) {
    _setupRoutes();
  }

  Router get router => _router;

  void registerHandler(String path, RequestHandler handler) {
    _handlers[path] = handler;
  }

  void unregisterHandler(String path) {
    _handlers.remove(path);
  }

  void _setupRoutes() {
    _router.get('/api/takeit/v1/info', _dispatch);
    _router.post('/api/takeit/v1/register', _dispatch);
    _router.post('/api/takeit/v1/room/invite', _dispatch);
    _router.post('/api/takeit/v1/room/accept', _dispatch);
    _router.post('/api/takeit/v1/room/leave', _dispatch);
    _router.post('/api/takeit/v1/room/decline', _dispatch);
    _router.post('/api/takeit/v1/room/alias-update', _dispatch);
    _router.post('/api/takeit/v1/message', _dispatch);
    _router.post('/api/takeit/v1/transfer/prepare-batch', _dispatch);
    _router.post('/api/takeit/v1/transfer/upload', _dispatch);
    _router.post('/api/takeit/v1/transfer/cancel', _dispatch);
    _router.post('/api/takeit/v1/transfer/cancel-batch', _dispatch);
    _router.post('/api/takeit/v1/clipboard', _dispatch);
    _router.post('/api/takeit/v1/room/sync', _dispatch);
    _router.get('/api/takeit/v1/ping', _dispatch);
    _router.post('/api/takeit/v1/quick/prepare-batch', _dispatch);
    _router.post('/api/takeit/v1/quick/upload', _dispatch);
    _router.post('/api/takeit/v1/quick/text', _dispatch);
    _router.post('/api/takeit/v1/quick/cancel', _dispatch);
  }

  Future<shelf.Response> _dispatch(shelf.Request request) async {
    final path = '/${request.url.path}';
    final handler = _handlers[path];
    if (handler != null) {
      return handler(request);
    }
    return shelf.Response.ok(
      jsonEncode({'status': 'not_implemented'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<void> start() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(_injectRemoteIp())
        .addMiddleware(_privateSubnetOnly())
        .addMiddleware(_rateLimiter())
        .addHandler(_router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    debugPrint('HTTP server running on port ${_server!.port}');
  }

  /// Reject requests from non-private (public) IP addresses.
  /// Allows: 10.x.x.x, 172.16-31.x.x, 192.168.x.x, 127.x.x.x, link-local.
  shelf.Middleware _privateSubnetOnly() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) {
        final ip = request.headers['X-Real-IP'] ?? '';
        if (!isPrivateIp(ip)) {
          debugPrint('Blocked non-private IP: $ip');
          return shelf.Response.forbidden(
            jsonEncode({'error': 'forbidden'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return innerHandler(request);
      };
    };
  }

  /// Whether [ip] is an IPv4 address in a private/LAN range.
  ///
  /// Fail-closed: an empty, non-IPv4, or unparseable value is rejected. The
  /// server only listens on IPv4 ([InternetAddress.anyIPv4]), so a legitimate
  /// peer always presents a dotted-quad here.
  @visibleForTesting
  static bool isPrivateIp(String ip) {
    if (ip.isEmpty) return false; // unknown origin — reject
    final parts = ip.split('.');
    if (parts.length != 4) return false; // not IPv4 — reject
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) {
      return false; // malformed octet — reject
    }
    final a = octets[0]!;
    final b = octets[1]!;
    // 127.x.x.x (loopback)
    if (a == 127) return true;
    // 10.x.x.x
    if (a == 10) return true;
    // 172.16.0.0 – 172.31.255.255
    if (a == 172 && b >= 16 && b <= 31) return true;
    // 192.168.x.x
    if (a == 192 && b == 168) return true;
    // 169.254.x.x (link-local)
    if (a == 169 && b == 254) return true;
    return false;
  }

  /// Simple per-IP rate limiter: max [_maxRequestsPerWindow] requests per
  /// [_rateLimitWindow]. Resets counters every window.
  shelf.Middleware _rateLimiter() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) {
        final ip = request.headers['X-Real-IP'] ?? 'unknown';
        final now = DateTime.now();

        if (now.difference(_windowStart) > _rateLimitWindow) {
          _requestCounts.clear();
          _windowStart = now;
        }

        final count = (_requestCounts[ip] ?? 0) + 1;
        _requestCounts[ip] = count;

        if (count > _maxRequestsPerWindow) {
          debugPrint('Rate limited IP: $ip ($count reqs in window)');
          return shelf.Response(
            429,
            body: jsonEncode({'error': 'too_many_requests'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        return innerHandler(request);
      };
    };
  }

  /// Middleware that captures the remote IP from the underlying HttpRequest
  /// and injects it as an 'X-Real-IP' header so handlers can access it.
  shelf.Middleware _injectRemoteIp() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) {
        final context = request.context;
        final httpRequest = context['shelf.io.connection_info'];
        final updatedRequest = request.change(
          headers: {
            if (httpRequest is HttpConnectionInfo)
              'X-Real-IP': httpRequest.remoteAddress.address,
          },
        );
        return innerHandler(updatedRequest);
      };
    };
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  bool get isRunning => _server != null;
}
