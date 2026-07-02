import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/network_constants.dart';

class MulticastMessage {
  final String alias;
  final String deviceType;
  final String fingerprint;
  final int port;
  final bool announce;
  final String ip;
  final String os;

  const MulticastMessage({
    required this.alias,
    required this.deviceType,
    required this.fingerprint,
    required this.port,
    required this.announce,
    required this.ip,
    this.os = '',
  });

  factory MulticastMessage.fromJson(
    Map<String, dynamic> json,
    String sourceIp,
  ) {
    return MulticastMessage(
      alias: json['alias'] as String,
      deviceType: json['deviceType'] as String,
      fingerprint: json['fingerprint'] as String,
      port: json['port'] as int,
      announce: json['announce'] as bool? ?? false,
      ip: sourceIp,
      os: json['os'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'alias': alias,
    'deviceType': deviceType,
    'fingerprint': fingerprint,
    'port': port,
    'announce': announce,
    'os': os,
  };
}

class MulticastService {
  static const multicastAddress = '224.0.0.167';
  static const multicastPort = kDefaultPort;
  static const heartbeatInterval = Duration(seconds: 5);
  static const fastHeartbeatInterval = Duration(seconds: 2);
  static const fastHeartbeatDuration = Duration(seconds: 30);
  static const deviceTimeout = Duration(seconds: 20);

  RawDatagramSocket? _socket;
  bool _starting = false;
  Timer? _heartbeatTimer;
  Timer? _fastToSlowTimer;
  final _messageController = StreamController<MulticastMessage>.broadcast();
  String? _ownFingerprint;

  Stream<MulticastMessage> get messages => _messageController.stream;
  bool get isRunning => _socket != null;

  Future<void> start(String fingerprint) async {
    if (_socket != null || _starting) return;
    _starting = true;
    _ownFingerprint = fingerprint;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        multicastPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );

      _socket!.broadcastEnabled = true;
      _socket!.multicastLoopback = false;

      final interfaces = await NetworkInterface.list();
      final multicastAddr = InternetAddress(multicastAddress);
      for (final iface in interfaces) {
        try {
          _socket!.joinMulticast(multicastAddr, iface);
        } catch (e) {
          debugPrint('Could not join multicast on ${iface.name}: $e');
        }
      }

      _socket!.listen(_handleEvent);
    } catch (e) {
      _socket?.close();
      _socket = null;
      rethrow;
    } finally {
      _starting = false;
    }
  }

  void _handleEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    try {
      final data = utf8.decode(datagram.data);
      final json = jsonDecode(data) as Map<String, dynamic>;
      final message = MulticastMessage.fromJson(json, datagram.address.address);

      if (message.fingerprint == _ownFingerprint) return;

      _messageController.add(message);
    } catch (e) {
      debugPrint('Multicast parse error: $e');
    }
  }

  void announce(MulticastMessage message) {
    if (_socket == null) return;
    final data = utf8.encode(jsonEncode(message.toJson()));
    _socket!.send(data, InternetAddress(multicastAddress), multicastPort);
  }

  void startHeartbeat(MulticastMessage message) {
    _heartbeatTimer?.cancel();
    _fastToSlowTimer?.cancel();

    announce(message);

    // Start with fast heartbeat (2s) for first 30 seconds
    _heartbeatTimer = Timer.periodic(fastHeartbeatInterval, (_) {
      announce(message);
    });

    // Switch to normal heartbeat after 30s
    _fastToSlowTimer = Timer(fastHeartbeatDuration, () {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
        announce(message);
      });
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _fastToSlowTimer?.cancel();
    _fastToSlowTimer = null;
  }

  Future<void> stop() async {
    stopHeartbeat();
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
    _messageController.close();
  }
}
