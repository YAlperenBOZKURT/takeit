import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  DiscoveryController(this._ref) : super([]) {
    _registerInfoHandler();
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

  Future<void> startDiscovery() async {
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

    _subscription = repo.devicesStream.listen((devices) {
      state = devices;
    });
  }

  Future<void> stopDiscovery() async {
    _subscription?.cancel();
    _subscription = null;
    await _ref.read(discoveryRepositoryProvider).stopDiscovery();
    state = [];
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
