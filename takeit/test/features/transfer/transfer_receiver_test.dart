// Full-stack receiver tests: real AppHttpServer + TransferNotifier handlers
// driven over loopback HTTP, exactly as a sending peer would.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/network/http_server.dart';
import 'package:takeit/core/services/transfer_queue_service.dart';
import 'package:takeit/features/discovery/presentation/providers/device_actions_provider.dart';
import 'package:takeit/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:takeit/features/history/presentation/providers/history_provider.dart';
import 'package:takeit/features/settings/presentation/providers/settings_provider.dart';
import 'package:takeit/features/transfer/domain/entities/transfer_session.dart';
import 'package:takeit/features/transfer/presentation/providers/transfer_provider.dart';
import 'package:takeit/main.dart';

/// Download-path notifier pinned to a temp dir so no path_provider plugin
/// call is needed.
class _FixedDownloadPath extends DownloadPathNotifier {
  _FixedDownloadPath(String path) {
    state = path;
  }
}

/// History notifier that skips disk persistence (no plugin in tests).
class _NoopHistory extends HistoryNotifier {
  @override
  Future<void> addRecord({
    required String fileName,
    required int fileSize,
    required String peerAlias,
    required String direction,
    String? fileMimeType,
    String? savePath,
  }) async {}
}

// NOTE: no TestWidgetsFlutterBinding here — it would install flutter_test's
// mock HttpOverrides, which blocks the real loopback HTTP these tests need.
void main() {
  late AppHttpServer server;
  late ProviderContainer container;
  late Directory downloadDir;
  late int port;

  const senderId = 'test-sender-fp';

  setUp(() async {
    downloadDir = await Directory.systemTemp.createTemp('takeit_recv_test');
    server = AppHttpServer(port: 0);
    await server.start();
    port = server.boundPort!;

    container = ProviderContainer(
      overrides: [
        httpServerProvider.overrideWithValue(server),
        fingerprintProvider.overrideWithValue('receiver-fp'),
        downloadPathProvider.overrideWith(
          (ref) => _FixedDownloadPath(downloadDir.path),
        ),
        historyProvider.overrideWith((ref) => _NoopHistory()),
      ],
    );

    // Instantiating the notifier registers the transfer HTTP handlers.
    container.read(transferProvider.notifier);
    // Trust the sender so prepare-batch auto-accepts without a dialog.
    container.read(trustedDevicesProvider.notifier).add(senderId);
  });

  tearDown(() async {
    container.dispose();
    await server.stop();
    try {
      await downloadDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Runs prepare-batch for one file and returns its sessionId and token.
  Future<(String, String)> prepare(String fileName, int fileSize) async {
    final client = HttpClient();
    final req = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/takeit/v1/transfer/prepare-batch'),
    );
    req.headers.contentType = ContentType.json;
    req.write(
      jsonEncode({
        'senderId': senderId,
        'senderAlias': 'Test Sender',
        'files': [
          {'fileName': fileName, 'fileSize': fileSize},
        ],
      }),
    );
    final res = await req.close();
    final body =
        jsonDecode(await res.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    client.close();

    final entry = (body['files'] as List).first as Map<String, dynamic>;
    expect(entry['accepted'], isTrue, reason: 'trusted sender must auto-accept');
    return (entry['sessionId'] as String, entry['token'] as String);
  }

  /// Uploads [bytes] for the given session and returns the HTTP status code.
  Future<int> upload(String sessionId, String token, List<int> bytes) async {
    final client = HttpClient();
    final req = await client.postUrl(
      Uri.parse(
        'http://127.0.0.1:$port/api/takeit/v1/transfer/upload'
        '?sessionId=$sessionId&token=$token',
      ),
    );
    req.headers.contentType = ContentType.binary;
    req.contentLength = bytes.length;
    req.add(bytes);
    final res = await req.close();
    await res.drain<void>();
    final status = res.statusCode;
    client.close();
    return status;
  }

  TransferSession sessionOf(String sessionId) => container
      .read(transferProvider)
      .firstWhere((s) => s.sessionId == sessionId);

  test('completed transfer is saved to disk and marked completed', () async {
    // 12 MB > kReceiveFlushBytes so the periodic-flush branch executes.
    final payload = List<int>.generate(12 * 1024 * 1024, (i) => i % 251);
    final (sessionId, token) = await prepare('big_ok.bin', payload.length);

    final status = await upload(sessionId, token, payload);

    expect(status, 200);
    expect(sessionOf(sessionId).status, TransferStatus.completed);
    final saved = File('${downloadDir.path}/big_ok.bin');
    expect(saved.existsSync(), isTrue);
    expect(saved.lengthSync(), payload.length);
  });

  test('truncated transfer fails and the partial file is deleted', () async {
    // Declare 1 MB in prepare-batch but deliver only 200 KB.
    final partial = List<int>.generate(200 * 1024, (i) => i % 251);
    final (sessionId, token) = await prepare('truncated.bin', 1024 * 1024);

    final status = await upload(sessionId, token, partial);

    expect(status, 500);
    expect(sessionOf(sessionId).status, TransferStatus.failed);
    expect(
      downloadDir.listSync(),
      isEmpty,
      reason: 'partial file must be deleted on failure',
    );
    expect(
      container.read(activeDownloadIdsProvider),
      isEmpty,
      reason: 'failed transfer must free its download slot',
    );
  });

  test('upload with a wrong token is rejected before any disk write',
      () async {
    final (sessionId, _) = await prepare('rejected.bin', 1024);

    final status = await upload(sessionId, 'wrong-token', [1, 2, 3]);

    expect(status, 403);
    expect(downloadDir.listSync(), isEmpty);
  });
}
