import 'package:shelf/shelf.dart' as shelf;

/// The remote IP captured by [AppHttpServer]'s X-Real-IP middleware, or null
/// when it could not be determined.
String? remoteIpOf(shelf.Request request) {
  final ip = request.headers['x-real-ip'];
  return (ip == null || ip.isEmpty) ? null : ip;
}

/// Whether [request] originates from one of [allowedIps].
///
/// Fail-closed: an unknown remote IP (missing header) or an IP not in the
/// allow-list returns false. Used to ensure room-scoped endpoints only accept
/// traffic from devices the user is actually in a room with.
bool isFromAllowedIp(shelf.Request request, Iterable<String> allowedIps) {
  final ip = remoteIpOf(request);
  if (ip == null) return false;
  return allowedIps.contains(ip);
}
