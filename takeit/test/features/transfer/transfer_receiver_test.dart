// Full-stack receiver tests: real AppHttpServer + TransferNotifier handlers
// driven over loopback HTTP, exactly as a sending peer would.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/network/http_server.dart';
import 'package:takeit/core/services/transfer_queue_service.dart';
import 'package:takeit/core/storage/settings_store.dart';
import 'package:takeit/features/discovery/presentation/providers/device_actions_provider.dart';
import 'package:takeit/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:takeit/features/history/presentation/providers/history_provider.dart';
import 'package:takeit/features/room/domain/entities/room.dart';
import 'package:takeit/features/room/domain/entities/room_member.dart';
import 'package:takeit/features/room/presentation/providers/room_provider.dart';
import 'package:takeit/features/transfer/domain/entities/transfer_session.dart';
import 'package:takeit/features/transfer/presentation/providers/transfer_provider.dart';
import 'package:takeit/main.dart';

/// Room notifier already in a room with the test sender (room transfers are
/// only accepted from room members).
class _InRoomWithSender extends RoomNotifier {
  _InRoomWithSender(super.ref, {required int senderPort}) {
    state = Room(
      id: 'room-1',
      hostFingerprint: 'test-sender-fp',
      members: [
        RoomMember(
          fingerprint: 'test-sender-fp',
          alias: 'Test Sender',
          ip: '127.0.0.1',
          port: senderPort,
          deviceType: 'desktop',
          status: MemberStatus.accepted,
        ),
      ],
      createdAt: DateTime.now(),
    );
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

  /// Short idle expiry so the batch-expiry tests run in well under a second.
  const acceptedIdleTimeout = Duration(milliseconds: 400);

  setUp(() async {
    downloadDir = await Directory.systemTemp.createTemp('takeit_recv_test');
    server = AppHttpServer(port: 0);
    await server.start();
    port = server.boundPort!;

    container = ProviderContainer(
      overrides: [
        httpServerProvider.overrideWithValue(server),
        fingerprintProvider.overrideWithValue('receiver-fp'),
        // Downloads pinned to a temp dir so no path_provider call is needed.
        settingsStoreProvider.overrideWithValue(
          SettingsStore.inMemory({'downloadPath': downloadDir.path}),
        ),
        historyProvider.overrideWith((ref) => _NoopHistory()),
        transferProvider.overrideWith(
          (ref) =>
              TransferNotifier(ref, acceptedIdleTimeout: acceptedIdleTimeout),
        ),
        roomProvider.overrideWith(
          (ref) => _InRoomWithSender(ref, senderPort: port),
        ),
      ],
    );

    // Instantiating the notifier registers the transfer HTTP handlers.
    container.read(transferProvider.notifier);
    container.read(roomProvider.notifier);
    // Trust the sender so prepare-batch auto-accepts without a dialog.
    container.read(trustedDevicesProvider.notifier).add(senderId, '127.0.0.1');
  });

  tearDown(() async {
    container.dispose();
    await server.stop();
    try {
      await downloadDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Runs prepare-batch for several files in one batch and returns each
  /// file's sessionId and token, in order.
  Future<List<(String, String)>> prepareBatch(List<(String, int)> files) async {
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
          for (final (name, size) in files)
            {'fileName': name, 'fileSize': size},
        ],
      }),
    );
    final res = await req.close();
    final body =
        jsonDecode(await res.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    client.close();

    final sessions = <(String, String)>[];
    for (final e in (body['files'] as List).cast<Map<String, dynamic>>()) {
      expect(e['accepted'], isTrue, reason: 'trusted sender must auto-accept');
      sessions.add((e['sessionId'] as String, e['token'] as String));
    }
    return sessions;
  }

  /// Runs prepare-batch for one file and returns its sessionId and token.
  Future<(String, String)> prepare(String fileName, int fileSize) async =>
      (await prepareBatch([(fileName, fileSize)])).single;

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

  /// Uploads [bytes] in [chunks] pieces spread over [duration], like a
  /// large file on a real network, and returns the HTTP status code.
  Future<int> uploadSlowly(
    String sessionId,
    String token,
    List<int> bytes, {
    required Duration duration,
    int chunks = 8,
  }) async {
    final client = HttpClient();
    final req = await client.postUrl(
      Uri.parse(
        'http://127.0.0.1:$port/api/takeit/v1/transfer/upload'
        '?sessionId=$sessionId&token=$token',
      ),
    );
    req.headers.contentType = ContentType.binary;
    req.contentLength = bytes.length;
    final chunkSize = (bytes.length / chunks).ceil();
    for (var i = 0; i < bytes.length; i += chunkSize) {
      req.add(bytes.sublist(i, (i + chunkSize).clamp(0, bytes.length)));
      await req.flush();
      await Future<void>.delayed(duration ~/ chunks);
    }
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
    expect(sessionOf(sessionId).savePath, saved.path);
    expect(
      downloadDir.listSync().map((e) => e.uri.pathSegments.last),
      ['big_ok.bin'],
      reason: 'no .part file may be left behind',
    );
  });

  test('a download in progress only exists as a .part file', () async {
    final payload = List<int>.generate(64 * 1024, (i) => i % 251);
    final (sessionId, token) = await prepare('slow.bin', payload.length);

    final done = uploadSlowly(
      sessionId,
      token,
      payload,
      duration: const Duration(milliseconds: 400),
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final midway = downloadDir
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .toList();
    expect(await done, 200);

    expect(midway, ['slow.bin.part']);
    expect(File('${downloadDir.path}/slow.bin').lengthSync(), payload.length);
  });

  test(
    'parallel downloads with the same name land in separate files',
    () async {
      final a = List<int>.filled(256 * 1024, 1);
      final b = List<int>.filled(256 * 1024, 2);
      final sessions = await prepareBatch([
        ('same.bin', a.length),
        ('same.bin', b.length),
      ]);

      final statuses = await Future.wait([
        upload(sessions[0].$1, sessions[0].$2, a),
        upload(sessions[1].$1, sessions[1].$2, b),
      ]);

      expect(statuses, [200, 200]);
      final fillBytes = <int>{};
      for (final name in ['same.bin', 'same_1.bin']) {
        final bytes = File('${downloadDir.path}/$name').readAsBytesSync();
        expect(bytes, hasLength(a.length), reason: name);
        // Each file holds exactly one sender's bytes — nothing interleaved.
        expect(bytes.toSet(), hasLength(1), reason: name);
        fillBytes.add(bytes.first);
      }
      expect(fillBytes, {1, 2});
    },
  );

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

  test('upload with a wrong token is rejected before any disk write', () async {
    final (sessionId, _) = await prepare('rejected.bin', 1024);

    final status = await upload(sessionId, 'wrong-token', [1, 2, 3]);

    expect(status, 403);
    expect(downloadDir.listSync(), isEmpty);
  });

  test('later files of a batch stay approved while an earlier file streams '
      'for longer than the idle timeout', () async {
    final first = List<int>.generate(64 * 1024, (i) => i % 251);
    final second = List<int>.generate(1024, (i) => i % 13);
    final sessions = await prepareBatch([
      ('first.bin', first.length),
      ('second.bin', second.length),
    ]);

    // Sequential, as the sender does it: the first upload alone outlasts
    // the idle timeout.
    final firstStatus = await uploadSlowly(
      sessions[0].$1,
      sessions[0].$2,
      first,
      duration: acceptedIdleTimeout * 2,
    );
    final secondStatus = await upload(sessions[1].$1, sessions[1].$2, second);

    expect(firstStatus, 200);
    expect(secondStatus, 200, reason: 'second file must not be rejected');
    expect(File('${downloadDir.path}/second.bin').lengthSync(), second.length);
  });

  test(
    'approved files are dropped once the batch sits idle too long',
    () async {
      final (sessionId, token) = await prepare('never_sent.bin', 16);

      await Future<void>.delayed(acceptedIdleTimeout * 2);
      final status = await upload(sessionId, token, List.filled(16, 1));

      expect(status, 403);
      expect(downloadDir.listSync(), isEmpty);
    },
  );

  test('a sender pushing more than the approved size is cut off', () async {
    final (sessionId, token) = await prepare('small.bin', 1024);

    int? status;
    try {
      status = await upload(sessionId, token, List<int>.filled(64 * 1024, 7));
    } on IOException {
      // The receiver stopped reading mid-body and the connection dropped.
      status = null;
    }

    // Refused either way: a 500 or the connection cut mid-body.
    expect(status, anyOf(500, isNull));
    expect(sessionOf(sessionId).status, TransferStatus.failed);
    // With the connection cut the client doesn't wait for the receiver's
    // cleanup, so give the .part deletion a moment.
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (downloadDir.listSync().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(downloadDir.listSync(), isEmpty, reason: 'nothing may be kept');
  });

  test('a cancel from the sender stops the download mid-way', () async {
    final payload = List<int>.generate(256 * 1024, (i) => i % 251);
    final (sessionId, token) = await prepare('cancelled.bin', payload.length);

    final upload = uploadSlowly(
      sessionId,
      token,
      payload,
      duration: const Duration(milliseconds: 600),
      chunks: 12,
    ).then<int?>((s) => s, onError: (_) => null);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final client = HttpClient();
    final req = await client.postUrl(
      Uri.parse(
        'http://127.0.0.1:$port/api/takeit/v1/transfer/cancel'
        '?sessionId=$sessionId',
      ),
    );
    await (await req.close()).drain<void>();
    client.close();

    expect(await upload, anyOf(500, isNull));
    expect(sessionOf(sessionId).status, TransferStatus.cancelled);
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (downloadDir.listSync().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(downloadDir.listSync(), isEmpty, reason: '.part must be removed');
  });

  test('room transfers from a device outside the room are refused', () async {
    await container.read(roomProvider.notifier).leaveRoom();

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
          {'fileName': 'x.bin', 'fileSize': 1},
        ],
      }),
    );
    final res = await req.close();
    await res.drain<void>();
    client.close();

    expect(res.statusCode, 403);
  });
}
