import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart' as shelf;

/// Largest JSON request body accepted (chat text, clipboard, quick text,
/// room control messages). File data goes through the streaming upload
/// endpoints, which are not subject to this.
const kMaxJsonBodyBytes = 1024 * 1024;

/// The request body exceeded [kMaxJsonBodyBytes]; answered with 413 by
/// [AppHttpServer].
class PayloadTooLargeException implements Exception {
  @override
  String toString() => 'Request body too large';
}

/// Reads and decodes a JSON body, refusing to buffer more than [maxBytes].
///
/// `request.readAsString()` would hold whatever a peer sends in memory — any
/// device on the LAN could exhaust it with one endless request.
Future<dynamic> readJsonBody(
  shelf.Request request, {
  int maxBytes = kMaxJsonBodyBytes,
}) async {
  final declared = request.contentLength;
  if (declared != null && declared > maxBytes) {
    throw PayloadTooLargeException();
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in request.read()) {
    bytes.add(chunk);
    if (bytes.length > maxBytes) throw PayloadTooLargeException();
  }
  return jsonDecode(utf8.decode(bytes.takeBytes()));
}
