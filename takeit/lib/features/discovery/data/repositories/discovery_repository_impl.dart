import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/local_ip.dart';
import '../../../../core/network/multicast_service.dart';
import '../../domain/entities/device.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../datasources/multicast_datasource.dart';

class DiscoveryRepositoryImpl implements DiscoveryRepository {
  final MulticastDatasource _datasource;
  final MulticastService _multicastService;

  /// Tests turn this off to avoid probing the real LAN.
  final bool _httpScanEnabled;
  bool _scanning = false;

  final Map<String, Device> _devices = {};
  final _devicesController = StreamController<List<Device>>.broadcast();
  Timer? _cleanupTimer;
  Timer? _httpScanTimer;
  MulticastMessage? _ownMessage;
  StreamSubscription? _deviceStreamSub;
  final Dio _scanClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 300),
      receiveTimeout: const Duration(milliseconds: 500),
      sendTimeout: const Duration(milliseconds: 300),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  DiscoveryRepositoryImpl(
    this._datasource,
    this._multicastService, {
    bool httpScan = true,
  }) : _httpScanEnabled = httpScan;

  /// Set while discovery is running (between start and stop).
  bool get _running => _ownMessage != null;

  @override
  Stream<List<Device>> get devicesStream => _devicesController.stream;

  @override
  Future<void> startDiscovery({
    required String alias,
    required String deviceType,
    required String fingerprint,
    required int port,
    String os = '',
  }) async {
    _ownMessage = MulticastMessage(
      alias: alias,
      deviceType: deviceType,
      fingerprint: fingerprint,
      port: port,
      announce: true,
      ip: '',
      os: os,
    );

    await _multicastService.start(fingerprint);

    // Cancel previous subscription to prevent listener leak
    await _deviceStreamSub?.cancel();
    _deviceStreamSub = _datasource.deviceStream.listen(
      (model) => _upsert(model.toEntity()),
    );

    _datasource.startHeartbeat(_ownMessage!);

    // Starting again while running must replace the timers, not stack them.
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _removeStaleDevices(),
    );

    // HTTP scan fallback: scan subnet every 10s
    _httpScanTimer?.cancel();
    if (!_httpScanEnabled) return;
    _runHttpScan(fingerprint);
    _httpScanTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _runHttpScan(fingerprint),
    );
  }

  @override
  Future<void> stopDiscovery() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _httpScanTimer?.cancel();
    _httpScanTimer = null;
    await _deviceStreamSub?.cancel();
    _deviceStreamSub = null;
    _datasource.stopHeartbeat();
    await _multicastService.stop();
    _ownMessage = null;
    _devices.clear();
    _emit();
  }

  @override
  void reAnnounce() {
    if (_ownMessage != null) {
      _datasource.announce(_ownMessage!);
    }
  }

  @override
  void updateAlias(String alias) {
    final own = _ownMessage;
    if (own == null || own.alias == alias) return;
    _ownMessage = MulticastMessage(
      alias: alias,
      deviceType: own.deviceType,
      fingerprint: own.fingerprint,
      port: own.port,
      announce: own.announce,
      ip: own.ip,
      os: own.os,
    );
    // The heartbeat captured the old message — restart it so every later
    // announcement carries the new alias (it also announces right away).
    _datasource.startHeartbeat(_ownMessage!);
  }

  @override
  void registerDevice(Device device) => _upsert(device);

  /// Records [device]. The list is only re-emitted when something visible
  /// changed — a heartbeat that just refreshes lastSeen is not worth a
  /// rebuild of every listener.
  void _upsert(Device device) {
    final previous = _devices[device.fingerprint];
    _devices[device.fingerprint] = device;
    if (previous == null ||
        previous.copyWith(lastSeen: device.lastSeen) != device) {
      _emit();
    }
  }

  // ─── HTTP Scan Fallback ───

  Future<void> _runHttpScan(String ownFingerprint) async {
    // A scan can outlast the timer interval — never run two at once.
    if (_scanning) return;
    _scanning = true;
    try {
      // LAN adapters only (no Docker/VPN/WSL/VM subnets), each /24 once.
      final subnets = {
        for (final ip in await listUsableLocalIps())
          if (ip.split('.').length == 4) ip.substring(0, ip.lastIndexOf('.')),
      };
      for (final subnet in subnets) {
        if (!_running) break;
        await _scanSubnet(subnet, ownFingerprint);
      }
    } catch (e) {
      debugPrint('HTTP scan error: $e');
    } finally {
      _scanning = false;
    }
  }

  /// Max concurrent HTTP probes to avoid flooding the network / UI thread.
  static const int _maxConcurrentProbes = 15;

  Future<void> _scanSubnet(String subnet, String ownFingerprint) async {
    final ips = List.generate(254, (i) => '$subnet.${i + 1}');
    var running = 0;
    var index = 0;
    final completer = Completer<void>();

    void startNext() {
      while (running < _maxConcurrentProbes && index < ips.length) {
        running++;
        final ip = ips[index++];
        _probeHost(ip, ownFingerprint).whenComplete(() {
          running--;
          if (index < ips.length) {
            startNext();
          } else if (running == 0) {
            completer.complete();
          }
        });
      }
      if (index >= ips.length && running == 0) {
        completer.complete();
      }
    }

    startNext();
    await completer.future;
  }

  Future<void> _probeHost(String ip, String ownFingerprint) async {
    try {
      final response = await _scanClient.get(
        'http://$ip:${MulticastService.multicastPort}/api/takeit/v1/info',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final fingerprint = data['fingerprint'] as String;
        if (fingerprint == ownFingerprint) return;
        // A probe answered after discovery was stopped — don't resurrect it.
        if (!_running) return;

        final device = Device(
          fingerprint: fingerprint,
          alias: data['alias'] as String,
          deviceType: data['deviceType'] as String,
          ip: ip,
          port: data['port'] as int,
          lastSeen: DateTime.now(),
          os: data['os'] as String? ?? '',
        );
        _upsert(device);
      }
    } catch (_) {
      // Expected — most IPs won't respond
    }
  }

  void _removeStaleDevices() {
    final now = DateTime.now();
    final stale = _devices.entries
        .where(
          (e) =>
              now.difference(e.value.lastSeen) > MulticastService.deviceTimeout,
        )
        .map((e) => e.key)
        .toList();

    if (stale.isEmpty) return;
    for (final key in stale) {
      _devices.remove(key);
    }
    _emit();
  }

  void _emit() {
    _devicesController.add(_devices.values.toList());
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _httpScanTimer?.cancel();
    _deviceStreamSub?.cancel();
    _devicesController.close();
  }
}
