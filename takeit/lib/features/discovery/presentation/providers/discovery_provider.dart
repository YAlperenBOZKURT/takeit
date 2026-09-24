import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf.dart' as shelf;
import '../../../../core/network/multicast_service.dart';
import '../../../../main.dart';
import '../../../nickname/presentation/providers/nickname_provider.dart';
import '../../data/datasources/multicast_datasource.dart';
import '../../data/repositories/discovery_repository_impl.dart';
import '../../domain/entities/device.dart';
import '../../domain/repositories/discovery_repository.dart';

final _multicastServiceProvider = Provider<MulticastService>((ref) {
  final service = MulticastService();
  ref.onDispose(() => service.dispose());
  return service;
});

final _multicastDatasourceProvider = Provider<MulticastDatasource>((ref) {
  return MulticastDatasource(ref.read(_multicastServiceProvider));
});

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  final repo = DiscoveryRepositoryImpl(
    ref.read(_multicastDatasourceProvider),
    ref.read(_multicastServiceProvider),
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

final fingerprintProvider = Provider<String>((ref) {
  throw UnimplementedError('fingerprintProvider must be overridden in main()');
});

final deviceTypeProvider = Provider<String>((ref) {
  if (Platform.isAndroid || Platform.isIOS) return 'mobile';
  return 'desktop';
});

final osProvider = Provider<String>((ref) {
  return Platform.operatingSystem;
});

final discoveryControllerProvider =
    StateNotifierProvider<DiscoveryController, List<Device>>((ref) {
      return DiscoveryController(ref);
    });

class DiscoveryController extends StateNotifier<List<Device>> {
  final Ref _ref;
  StreamSubscription<List<Device>>? _subscription;

  /// Start/stop run strictly one after another. Overlapping them (a stop
  /// not awaited before the next start) let the stop close the multicast
  /// socket that the start had just decided to reuse, leaving discovery
  /// silently dead.
  Future<void> _lifecycle = Future.value();

  DiscoveryController(this._ref) : super([]) {
    _registerInfoHandler();
    // The heartbeat keeps broadcasting the alias captured at start — push
    // nickname changes into it.
    _ref.listen<String>(nicknameProvider, (prev, next) {
      if (prev != next) {
        _ref.read(discoveryRepositoryProvider).updateAlias(next);
      }
    });
  }

  Future<void> _serialized(Future<void> Function() op) {
    final next = _lifecycle.then((_) => op());
    _lifecycle = next.catchError((Object e) {
      debugPrint('Discovery start/stop failed: $e');
    });
    return next;
  }

  void _registerInfoHandler() {
    final server = _ref.read(httpServerProvider);
    server.registerHandler('/api/takeit/v1/info', _handleInfo);
  }

  Future<shelf.Response> _handleInfo(shelf.Request request) async {
    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);
    final deviceType = _ref.read(deviceTypeProvider);
    final os = _ref.read(osProvider);

    return shelf.Response.ok(
      jsonEncode({
        'fingerprint': fingerprint,
        'alias': alias,
        'deviceType': deviceType,
        'port': MulticastService.multicastPort,
        'os': os,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<void> startDiscovery() => _serialized(_start);

  Future<void> stopDiscovery() => _serialized(_stop);

  /// Stop then start, as one step (e.g. after a long background).
  Future<void> restartDiscovery() => _serialized(() async {
    await _stop();
    await _start();
  });

  Future<void> _start() async {
    final repo = _ref.read(discoveryRepositoryProvider);
    final alias = _ref.read(nicknameProvider);
    final fingerprint = _ref.read(fingerprintProvider);
    final deviceType = _ref.read(deviceTypeProvider);
    final os = _ref.read(osProvider);

    await repo.startDiscovery(
      alias: alias,
      deviceType: deviceType,
      fingerprint: fingerprint,
      port: MulticastService.multicastPort,
      os: os,
    );

    await _subscription?.cancel();
    _subscription = repo.devicesStream.listen((devices) {
      state = devices;
    });
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _ref.read(discoveryRepositoryProvider).stopDiscovery();
    if (mounted) state = [];
  }

  void reAnnounce() {
    _ref.read(discoveryRepositoryProvider).reAnnounce();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
