import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/transfer/data/services/file_transfer_service.dart';

/// Creates a temp file of [sizeBytes] filled with a repeating byte pattern.
Future<File> _makeTempFile(int sizeBytes) async {
  final dir = await Directory.systemTemp.createTemp('takeit_svc_test');
  final file = File('${dir.path}/payload.bin');
  final sink = file.openWrite();
  final chunk = List<int>.generate(1024 * 1024, (i) => i % 251);
  for (var written = 0; written < sizeBytes; written += chunk.length) {
    sink.add(chunk);
  }
  await sink.flush();
  await sink.close();
  return file;
}

void main() {
  final tempFiles = <File>[];
  final servers = <HttpServer>[];

  tearDown(() async {
    for (final s in servers) {
      await s.close(force: true);
    }
    servers.clear();
    for (final f in tempFiles) {
      try {
        await f.parent.delete(recursive: true);
      } catch (_) {}
    }
    tempFiles.clear();
  });

  Future<HttpServer> startServer(
    Future<void> Function(HttpRequest req) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servers.add(server);
    server.listen((req) async {
      try {
        await handler(req);
      } catch (_) {}
    });
    return server;
  }

  test(
    // Regression guard for the 30s dio sendTimeout that aborted every upload
    // outlasting it (8 GB files died at ~10-14%). Deliberately slow (~35s):
    // the property "an upload longer than 30s survives" cannot be proven
    // faster.
    'upload taking longer than 30 seconds does not fail',
    () async {
      final file = await _makeTempFile(150 * 1024 * 1024);
      tempFiles.add(file);

      var serverBytes = 0;
      final server = await startServer((req) async {
        await for (final chunk in req) {
          serverBytes += chunk.length;
          // Throttle reads so the whole upload takes well over 30s.
          await Future.delayed(const Duration(milliseconds: 25));
        }
        req.response.statusCode = 200;
        req.response.write('{"status":"completed"}');
        await req.response.close();
      });

      final service = FileTransferService();
      var lastSent = 0;
      final sw = Stopwatch()..start();
      await service.sendFile(
        targetIp: '127.0.0.1',
        targetPort: server.port,
        filePath: file.path,
        sessionId: 's1',
        fileId: 'f1',
        token: 't1',
        onProgress: (sent, total) => lastSent = sent,
      );
      sw.stop();

      expect(sw.elapsed, greaterThan(const Duration(seconds: 30)));
      expect(serverBytes, file.lengthSync());
      expect(lastSent, file.lengthSync());
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('upload with no progress fails with a clear TimeoutException', () async {
    final file = await _makeTempFile(16 * 1024 * 1024);
    tempFiles.add(file);

    // Accept the connection but never read the body and never respond.
    final server = await startServer((req) async {
      req.listen(null).pause();
      await Completer<void>().future;
    });

    final service = FileTransferService(
      stallTimeout: const Duration(seconds: 2),
      stallCheckInterval: const Duration(milliseconds: 200),
    );

    Object? caught;
    try {
      await service.sendFile(
        targetIp: '127.0.0.1',
        targetPort: server.port,
        filePath: file.path,
        sessionId: 's1',
        fileId: 'f1',
        token: 't1',
        onProgress: (_, _) {},
      );
    } catch (e) {
      caught = e;
    }

    expect(caught, isA<TimeoutException>());
    expect('$caught', contains('no progress'));
  });

  test('user cancel surfaces as a dio cancel, not a failure', () async {
    final file = await _makeTempFile(32 * 1024 * 1024);
    tempFiles.add(file);

    final server = await startServer((req) async {
      await for (final _ in req) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    });

    final service = FileTransferService();
    final cancelToken = CancelToken();
    Timer(const Duration(milliseconds: 500), () {
      cancelToken.cancel('user_cancelled');
    });

    Object? caught;
    try {
      await service.sendFile(
        targetIp: '127.0.0.1',
        targetPort: server.port,
        filePath: file.path,
        sessionId: 's1',
        fileId: 'f1',
        token: 't1',
        cancelToken: cancelToken,
        onProgress: (_, _) {},
      );
    } catch (e) {
      caught = e;
    }

    // The provider maps this to TransferStatus.cancelled via
    // CancelToken.isCancel — it must not arrive as a stall TimeoutException.
    expect(caught, isA<DioException>());
    expect(CancelToken.isCancel(caught as DioException), isTrue);
  });

  test('quick send path and room path hit their own endpoints', () async {
    final file = await _makeTempFile(1024 * 1024);
    tempFiles.add(file);

    final seenUris = <Uri>[];
    final seenContentLengths = <int>[];
    final server = await startServer((req) async {
      seenUris.add(req.uri);
      seenContentLengths.add(req.headers.contentLength);
      await req.drain<void>();
      req.response.statusCode = 200;
      req.response.write('{"status":"completed"}');
      await req.response.close();
    });

    final service = FileTransferService();

    // Room transfer: default path, fileId present.
    await service.sendFile(
      targetIp: '127.0.0.1',
      targetPort: server.port,
      filePath: file.path,
      sessionId: 'room-session',
      fileId: 'room-file',
      token: 'room-token',
      onProgress: (_, _) {},
    );

    // Quick send: same code path, quick endpoint, no fileId.
    await service.sendFile(
      targetIp: '127.0.0.1',
      targetPort: server.port,
      filePath: file.path,
      sessionId: 'quick-session',
      token: 'quick-token',
      uploadPath: '/api/takeit/v1/quick/upload',
      onProgress: (_, _) {},
    );

    expect(seenUris, hasLength(2));
    expect(seenUris[0].path, '/api/takeit/v1/transfer/upload');
    expect(seenUris[0].queryParameters['sessionId'], 'room-session');
    expect(seenUris[0].queryParameters['fileId'], 'room-file');
    expect(seenUris[0].queryParameters['token'], 'room-token');
    expect(seenUris[1].path, '/api/takeit/v1/quick/upload');
    expect(seenUris[1].queryParameters['sessionId'], 'quick-session');
    expect(seenUris[1].queryParameters.containsKey('fileId'), isFalse);
    expect(seenUris[1].queryParameters['token'], 'quick-token');
    expect(seenContentLengths, everyElement(file.lengthSync()));
  });
}
