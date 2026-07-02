import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/multicast_service.dart';
import '../../domain/entities/device.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../datasources/multicast_datasource.dart';

class DiscoveryRepositoryImpl implements DiscoveryRepository {
  final MulticastDatasource _datasource;
  final MulticastService _multicastService;

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

  DiscoveryRepositoryImpl(this._datasource, this._multicastService);

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
    _deviceStreamSub = _datasource.deviceStream.listen((model) {
      final device = model.toEntity();
      _devices[device.fingerprint] = device;
      _emit();
    });

    _datasource.startHeartbeat(_ownMessage!);

    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _removeStaleDevices(),
    );

    // HTTP scan fallback: scan subnet every 10s
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
  void registerDevice(Device device) {
    _devices[device.fingerprint] = device;
    _emit();
  }

  // ─── HTTP Scan Fallback ───

  Future<void> _runHttpScan(String ownFingerprint) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          await _scanSubnet(subnet, ownFingerprint);
        }
      }
    } catch (e) {
      debugPrint('HTTP scan error: $e');
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

        final device = Device(
          fingerprint: fingerprint,
          alias: data['alias'] as String,
          deviceType: data['deviceType'] as String,
          ip: ip,
          port: data['port'] as int,
          lastSeen: DateTime.now(),
          os: data['os'] as String? ?? '',
        );
        _devices[device.fingerprint] = device;
        _emit();
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
