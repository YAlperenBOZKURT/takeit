import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/network/multicast_service.dart';
import 'package:takeit/features/discovery/data/datasources/multicast_datasource.dart';
import 'package:takeit/features/discovery/data/repositories/discovery_repository_impl.dart';
import 'package:takeit/features/discovery/domain/entities/device.dart';

/// In-memory multicast service: records what would be sent and lets the test
/// inject received announcements.
class _FakeMulticast implements MulticastService {
  final _incoming = StreamController<MulticastMessage>.broadcast();
  final heartbeats = <MulticastMessage>[];
  bool running = false;

  void receive(MulticastMessage m) => _incoming.add(m);

  @override
  Stream<MulticastMessage> get messages => _incoming.stream;
  @override
  bool get isRunning => running;
  @override
  Future<void> start(String fingerprint) async => running = true;
  @override
  Future<void> stop() async => running = false;
  @override
  void announce(MulticastMessage message) {}
  @override
  void startHeartbeat(MulticastMessage message) => heartbeats.add(message);
  @override
  void stopHeartbeat() {}
  @override
  void dispose() => _incoming.close();
}

MulticastMessage _peer({String alias = 'Peer'}) => MulticastMessage(
  alias: alias,
  deviceType: 'desktop',
  fingerprint: 'peer-fp',
  port: 53317,
  announce: true,
  ip: '192.168.1.20',
);

void main() {
  late _FakeMulticast multicast;
  late DiscoveryRepositoryImpl repo;
  late List<List<Device>> emissions;

  setUp(() {
    multicast = _FakeMulticast();
    repo = DiscoveryRepositoryImpl(
      MulticastDatasource(multicast),
      multicast,
      httpScan: false,
    );
    emissions = [];
    repo.devicesStream.listen(emissions.add);
  });

  tearDown(() {
    repo.dispose();
    multicast.dispose();
  });

  Future<void> start() => repo.startDiscovery(
    alias: 'Me',
    deviceType: 'desktop',
    fingerprint: 'my-fp',
    port: 53317,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'repeated heartbeats from an unchanged peer emit the list once',
    () async {
      await start();

      multicast.receive(_peer());
      multicast.receive(_peer());
      multicast.receive(_peer());
      await settle();

      expect(emissions, hasLength(1));
      expect(emissions.single.single.alias, 'Peer');
    },
  );

  test('a peer changing its alias is re-emitted', () async {
    await start();

    multicast.receive(_peer());
    multicast.receive(_peer(alias: 'Renamed'));
    await settle();

    expect(emissions, hasLength(2));
    expect(emissions.last.single.alias, 'Renamed');
  });

  test('starting twice does not double the device stream', () async {
    await start();
    await start();

    multicast.receive(_peer());
    await settle();

    expect(emissions, hasLength(1));
  });

  test('updateAlias restarts the heartbeat with the new alias', () async {
    await start();
    expect(multicast.heartbeats.last.alias, 'Me');

    repo.updateAlias('NewMe');

    expect(multicast.heartbeats.last.alias, 'NewMe');
    expect(multicast.heartbeats.last.fingerprint, 'my-fp');
  });

  test('updateAlias is a no-op while discovery is stopped', () async {
    await start();
    await repo.stopDiscovery();
    final before = multicast.heartbeats.length;

    repo.updateAlias('NewMe');

    expect(multicast.heartbeats, hasLength(before));
  });

  test('stop clears the list and releases the socket', () async {
    await start();
    multicast.receive(_peer());
    await settle();

    await repo.stopDiscovery();
    await settle();

    expect(emissions.last, isEmpty);
    expect(multicast.running, isFalse);
  });
}
