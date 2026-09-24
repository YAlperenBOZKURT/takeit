import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/network/http_server.dart';
import 'package:takeit/features/discovery/domain/entities/device.dart';
import 'package:takeit/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:takeit/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:takeit/features/nickname/presentation/providers/nickname_provider.dart';
import 'package:takeit/main.dart';

/// Mirrors MulticastService's real semantics: start() is a no-op while the
/// socket is still open, and stop() takes a moment to close it.
class _FakeRepo implements DiscoveryRepository {
  bool running = false;
  final aliases = <String>[];
  final _devices = StreamController<List<Device>>.broadcast();

  @override
  Stream<List<Device>> get devicesStream => _devices.stream;

  @override
  Future<void> startDiscovery({
    required String alias,
    required String deviceType,
    required String fingerprint,
    required int port,
    String os = '',
  }) async {
    if (running) return; // socket still open — reused
    running = true;
  }

  @override
  Future<void> stopDiscovery() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    running = false;
  }

  @override
  void reAnnounce() {}

  @override
  void updateAlias(String alias) => aliases.add(alias);

  @override
  void registerDevice(Device device) {}
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [
        httpServerProvider.overrideWithValue(AppHttpServer(port: 0)),
        fingerprintProvider.overrideWithValue('my-fp'),
        initialNicknameProvider.overrideWithValue('Old'),
        discoveryRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() => container.dispose());

  DiscoveryController controller() =>
      container.read(discoveryControllerProvider.notifier);

  test('restart leaves discovery running', () async {
    await controller().startDiscovery();

    await controller().restartDiscovery();

    expect(repo.running, isTrue);
  });

  test('an un-awaited stop followed by start still ends up running', () async {
    await controller().startDiscovery();

    // The pattern the app used to have: stop() fired without await.
    unawaited(controller().stopDiscovery());
    await controller().startDiscovery();
    // Let any stop still in flight finish before checking.
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(repo.running, isTrue, reason: 'start must wait for the stop');
  });

  test('a failing start does not wedge later start/stop calls', () async {
    final failing = _ThrowingOnceRepo();
    final c = ProviderContainer(
      overrides: [
        httpServerProvider.overrideWithValue(AppHttpServer(port: 0)),
        fingerprintProvider.overrideWithValue('my-fp'),
        discoveryRepositoryProvider.overrideWithValue(failing),
      ],
    );
    addTearDown(c.dispose);
    final ctrl = c.read(discoveryControllerProvider.notifier);

    await expectLater(ctrl.startDiscovery(), throwsA(isA<StateError>()));
    await ctrl.startDiscovery();

    expect(failing.running, isTrue);
  });

  test('a nickname change is pushed into the announcements', () async {
    controller();

    await container.read(nicknameProvider.notifier).setNickname('New');

    expect(repo.aliases, ['New']);
  });
}

class _ThrowingOnceRepo extends _FakeRepo {
  bool _thrown = false;

  @override
  Future<void> startDiscovery({
    required String alias,
    required String deviceType,
    required String fingerprint,
    required int port,
    String os = '',
  }) async {
    if (!_thrown) {
      _thrown = true;
      throw StateError('bind failed');
    }
    return super.startDiscovery(
      alias: alias,
      deviceType: deviceType,
      fingerprint: fingerprint,
      port: port,
      os: os,
    );
  }
}
