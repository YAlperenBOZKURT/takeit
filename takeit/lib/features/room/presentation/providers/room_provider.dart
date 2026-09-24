import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/http_client.dart';
import '../../../../core/network/local_ip.dart';
import '../../../../core/network/request_origin.dart';
import '../../../../core/constants/network_constants.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/transfer_queue_service.dart';
import '../../../../core/services/window_alert_service.dart';
import '../../../../main.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../discovery/domain/entities/device.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../nickname/presentation/providers/nickname_provider.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/room_member.dart';
import 'package:shelf/shelf.dart' as shelf;

final roomProvider = StateNotifierProvider<RoomNotifier, Room?>((ref) {
  return RoomNotifier(ref);
});

/// How long a room invite stays valid — on the host (the pending member is
/// auto-declined) and on the invitee (the invite is dropped from the queue).
const kInviteTimeout = Duration(seconds: 120);

/// Queue of pending room invites — multiple can arrive concurrently.
/// Device list listens and shows the first one; after it's resolved, the next pops up.
final roomInvitesProvider = StateProvider<List<Map<String, dynamic>>>(
  (ref) => [],
);

/// Holds connection warning messages for UI display.
final connectionWarningProvider = StateProvider<String?>((ref) => null);

/// Holds pending room info while waiting for accepts (host side only).
/// This is NOT an active room — just tracking who we invited.
final pendingRoomProvider = StateProvider<_PendingRoom?>((ref) => null);

class _PendingRoom {
  final String roomId;
  final String hostFingerprint;
  final List<RoomMember> members;

  _PendingRoom({
    required this.roomId,
    required this.hostFingerprint,
    required this.members,
  });
}

class RoomNotifier extends StateNotifier<Room?> {
  final Ref _ref;
  final Dio _client = createHttpClient();
  final Duration _connectionCheckInterval;
  final Duration _inviteTimeout;
  Timer? _connectionCheckTimer;
  final Map<String, int> _failedPings =
      {}; // fingerprint → consecutive failures
  Timer? _syncDebounce; // debounce for _broadcastMemberSync
  bool _isCheckingConnections = false;

  /// Stamped on every roster sync the host sends, so members can drop a
  /// sync that arrives after a newer one.
  int _syncSeq = 0;

  /// Highest roster sync sequence applied, per room (member side).
  final Map<String, int> _lastSyncSeq = {};

  RoomNotifier(
    this._ref, {
    Duration connectionCheckInterval = const Duration(seconds: 5),
    Duration inviteTimeout = kInviteTimeout,
  }) : _connectionCheckInterval = connectionCheckInterval,
       _inviteTimeout = inviteTimeout,
       super(null) {
    _registerInviteHandler();
    _startConnectionMonitor();
    _watchDeviceDisappearance();
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _syncDebounce?.cancel();
    super.dispose();
  }

  /// Runs for the notifier's whole lifetime: it idles while there is no
  /// room and picks up the next one on its own.
  void _startConnectionMonitor() {
    _connectionCheckTimer = Timer.periodic(
      _connectionCheckInterval,
      (_) => _checkConnections(),
    );
  }

  /// Ends the current room locally.
  void _dissolveRoom() {
    _failedPings.clear();
    _lastSyncSeq.clear();
    state = null;
  }

  /// This device's actual HTTP port (tests bind an ephemeral one).
  int get _ownPort => _ref.read(httpServerProvider).boundPort ?? kDefaultPort;

  /// Force an immediate connection check (e.g., on app resume).
  void checkConnectionsNow() => _checkConnections();

  /// Watch the discovery list — when a device disappears, auto-decline its
  /// pending invites and transfer approvals.
  void _watchDeviceDisappearance() {
    _ref.listen<List<Device>>(discoveryControllerProvider, (prev, next) {
      final previousFps = (prev ?? []).map((d) => d.fingerprint).toSet();
      final currentFps = next.map((d) => d.fingerprint).toSet();
      final disappeared = previousFps.difference(currentFps);

      for (final fp in disappeared) {
        _handleDeviceDisappeared(fp);
      }
    });
  }

  void _handleDeviceDisappeared(String fingerprint) {
    final invites = _ref.read(roomInvitesProvider);
    final filtered = invites
        .where((i) => i['hostFingerprint'] != fingerprint)
        .toList();
    if (filtered.length != invites.length) {
      debugPrint('Auto-declining invite(s) from offline device $fingerprint');
      _ref.read(roomInvitesProvider.notifier).state = filtered;
    }

    _ref.read(transferQueueProvider).declineAllFromSender(fingerprint);
  }

  void _checkConnections() {
    if (_isCheckingConnections || state == null) return;
    _isCheckingConnections = true;
    final members = state!.members
        .where(
          (m) =>
              m.status == MemberStatus.accepted ||
              m.status == MemberStatus.offline,
        )
        .toList();
    Future.wait(
      members.map(_pingMember),
    ).whenComplete(() => _isCheckingConnections = false);
  }

  Future<void> _pingMember(RoomMember member) async {
    final roomId = state?.id;
    try {
      final response = await _client.get(
        'http://${member.ip}:${member.port}/api/takeit/v1/ping',
        options: Options(
          receiveTimeout: const Duration(seconds: 3),
          sendTimeout: const Duration(seconds: 2),
        ),
      );

      // The room may have ended or been replaced while the ping was in
      // flight — its result says nothing about the current room.
      if (!mounted || state?.id != roomId) return;

      if (response.statusCode == 200) {
        // Ghost-member check: peer is reachable but has no active room (they
        // were force-killed and restarted with fresh state). Eject immediately.
        final peerRoomId = response.data is Map
            ? (response.data as Map)['roomId'] as String?
            : null;
        if (state != null && peerRoomId != state!.id) {
          debugPrint(
            '${member.alias} reachable but not in our room — ejecting (ghost)',
          );
          _failedPings.remove(member.fingerprint);
          _handleGhostMember(member);
          return;
        }

        _failedPings.remove(member.fingerprint);

        if (member.status == MemberStatus.offline) {
          _updateMemberStatus(member.fingerprint, MemberStatus.accepted);
          _ref.read(connectionWarningProvider.notifier).state =
              '${member.alias} reconnected';
        }
        return;
      }
    } catch (_) {}

    if (!mounted || state?.id != roomId) return;
    final failures = (_failedPings[member.fingerprint] ?? 0) + 1;
    _failedPings[member.fingerprint] = failures;

    if (failures >= 2 && member.status == MemberStatus.accepted) {
      _updateMemberStatus(member.fingerprint, MemberStatus.offline);
      _ref.read(connectionWarningProvider.notifier).state =
          '${member.alias} disconnected';

      if (!isHost && member.fingerprint == state?.hostFingerprint) {
        debugPrint('Host went offline — dissolving room');
        _dissolveRoom();
        return;
      }

      // Host: sync updated status; room auto-dissolves via _updateMemberStatus
      // if no accepted/pending remain.
      if (isHost) _scheduleMemberSync();
    }
  }

  /// Peer responded with a different (or null) roomId — they were force-killed
  /// and came back fresh. Clean up our side so the stale entry disappears.
  void _handleGhostMember(RoomMember member) {
    if (state == null) return;
    _ref.read(connectionWarningProvider.notifier).state =
        '${member.alias} left';

    if (!isHost && member.fingerprint == state!.hostFingerprint) {
      debugPrint('Host is ghost — dissolving room');
      _dissolveRoom();
      return;
    }

    // Drop the member entirely (not just offline — they're gone).
    final updated = state!.members
        .where((m) => m.fingerprint != member.fingerprint)
        .toList();
    state = state!.copyWith(members: updated);

    if (isHost) {
      // Sync updated roster to remaining peers so they drop the ghost too.
      _scheduleMemberSync();
    }

    if (updated.isEmpty) _dissolveRoom();
  }

  /// Debounced member sync — collects multiple status changes in 1 second
  /// and sends a single broadcast instead of one per failure.
  void _scheduleMemberSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 1), () {
      _broadcastMemberSync();
    });
  }

  void _registerInviteHandler() {
    final server = _ref.read(httpServerProvider);
    server.registerHandler('/api/takeit/v1/room/invite', _handleInvite);
    server.registerHandler('/api/takeit/v1/room/accept', _handleAccept);
    server.registerHandler('/api/takeit/v1/room/leave', _handleLeave);
    server.registerHandler('/api/takeit/v1/room/decline', _handleDecline);
    server.registerHandler('/api/takeit/v1/room/sync', _handleSync);
    server.registerHandler('/api/takeit/v1/ping', _handlePing);
    server.registerHandler(
      '/api/takeit/v1/room/alias-update',
      _handleAliasUpdate,
    );
  }

  Future<shelf.Response> _handleAliasUpdate(shelf.Request request) async {
    final body = jsonDecode(await request.readAsString());
    final roomId = body['roomId'] as String?;
    final fingerprint = body['fingerprint'] as String?;
    final newAlias = body['alias'] as String?;

    if (state == null ||
        roomId == null ||
        fingerprint == null ||
        newAlias == null) {
      return shelf.Response.notFound('');
    }
    if (state!.id != roomId || !isHost) {
      return shelf.Response.notFound('');
    }

    final updated = state!.members.map((m) {
      if (m.fingerprint == fingerprint) {
        return RoomMember(
          fingerprint: m.fingerprint,
          alias: newAlias,
          ip: m.ip,
          port: m.port,
          deviceType: m.deviceType,
          status: m.status,
        );
      }
      return m;
    }).toList();

    state = state!.copyWith(members: updated);
    _broadcastMemberSync();

    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Called from settings/nickname change — propagates new alias to peers.
  Future<void> notifyAliasChange() async {
    final room = state;
    if (room == null) return;

    if (isHost) {
      // Host alias change → rebroadcast full sync so every member sees it.
      await _broadcastMemberSync();
      return;
    }

    // Non-host → notify host; host rebroadcasts to everyone.
    final host = room.members.firstWhere(
      (m) => m.fingerprint == room.hostFingerprint,
      orElse: () => room.members.first,
    );
    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);
    try {
      await _client.post(
        'http://${host.ip}:${host.port}/api/takeit/v1/room/alias-update',
        data: {'roomId': room.id, 'fingerprint': fingerprint, 'alias': alias},
      );
    } catch (e) {
      debugPrint('Alias sync to host failed: $e');
    }
  }

  Future<shelf.Response> _handleInvite(shelf.Request request) async {
    final body = jsonDecode(await request.readAsString());
    if (body is! Map<String, dynamic> ||
        body['roomId'] is! String ||
        body['hostFingerprint'] is! String ||
        body['hostAlias'] is! String) {
      return shelf.Response.badRequest(body: 'Missing required fields');
    }
    final invite = body;
    // Use X-Real-IP injected by middleware, fallback to payload
    invite['hostIp'] = remoteIpOf(request) ?? invite['hostIp'] ?? '';
    if (invite['hostPort'] is! int) invite['hostPort'] = kDefaultPort;

    // Dedup by hostFingerprint — new invite from same person replaces the old one (LIFO).
    final hostFingerprint = invite['hostFingerprint'] as String?;
    final current = _ref.read(roomInvitesProvider);
    final filtered = current
        .where((i) => i['hostFingerprint'] != hostFingerprint)
        .toList();
    _ref.read(roomInvitesProvider.notifier).state = [...filtered, invite];

    // The host stops honouring this invite after kInviteTimeout, so drop it
    // here too — accepting it later would join a room that no longer exists.
    Timer(_inviteTimeout, () {
      if (mounted) _removeInviteFromQueue(invite);
    });

    final hostAlias = invite['hostAlias'] as String;
    NotificationService.notifyRoomInvite(hostAlias);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      WindowAlertService.flashWindow();
    }

    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  bool get isHost {
    final fp = _ref.read(fingerprintProvider);
    if (state != null) return state!.hostFingerprint == fp;
    final pending = _ref.read(pendingRoomProvider);
    if (pending != null) return pending.hostFingerprint == fp;
    return false;
  }

  Future<void> createRoom(List<Device> selectedDevices) async {
    // If there's already an active room with the same single member, reuse it
    if (selectedDevices.length == 1 && state != null) {
      final targetFp = selectedDevices.first.fingerprint;
      final existingMember = state!.members
          .where(
            (m) =>
                m.fingerprint == targetFp && m.status == MemberStatus.accepted,
          )
          .firstOrNull;
      if (existingMember != null) {
        return;
      }
    }

    if (state != null) {
      await leaveRoom();
    }
    _ref.read(pendingRoomProvider.notifier).state = null;
    _ref.read(chatProvider.notifier).clearMessages();

    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);
    final roomId = const Uuid().v4();
    final hostPort = _ownPort;
    final preferredPeerIp = selectedDevices.isNotEmpty
        ? selectedDevices.first.ip
        : null;
    final hostIp = await _getLocalIp(preferredPeerIp: preferredPeerIp);

    final members = selectedDevices
        .map(
          (d) => RoomMember(
            fingerprint: d.fingerprint,
            alias: d.alias,
            ip: d.ip,
            port: d.port,
            deviceType: d.deviceType,
            status: MemberStatus.pending,
          ),
        )
        .toList();

    // Don't create room yet — just track pending invites
    _ref.read(pendingRoomProvider.notifier).state = _PendingRoom(
      roomId: roomId,
      hostFingerprint: fingerprint,
      members: members,
    );

    for (final member in members) {
      _sendInvite(member, roomId, alias, fingerprint, hostIp, hostPort);
    }
  }

  /// Create a room by directly inviting a peer at [ip]:[kDefaultPort]
  /// without going through mDNS discovery. The peer's real fingerprint
  /// and alias are filled in when the accept arrives.
  Future<void> createRoomByIp(String ip) async {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return;

    if (state != null) {
      await leaveRoom();
    }
    _ref.read(pendingRoomProvider.notifier).state = null;
    _ref.read(chatProvider.notifier).clearMessages();

    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);
    final roomId = const Uuid().v4();
    final hostPort = _ownPort;
    final hostIp = await _getLocalIp(preferredPeerIp: trimmed);

    final placeholder = RoomMember(
      fingerprint: 'manual:$trimmed',
      alias: trimmed,
      ip: trimmed,
      port: kDefaultPort,
      deviceType: 'unknown',
      status: MemberStatus.pending,
    );

    _ref.read(pendingRoomProvider.notifier).state = _PendingRoom(
      roomId: roomId,
      hostFingerprint: fingerprint,
      members: [placeholder],
    );

    _sendInvite(placeholder, roomId, alias, fingerprint, hostIp, hostPort);
  }

  /// When a manual-invite peer accepts, swap the `manual:$ip` placeholder
  /// fingerprint for the real one so subsequent ping/sync work normally.
  void _replaceManualPlaceholderInRoom(
    String memberIp,
    String realFingerprint,
  ) {
    if (state == null || memberIp.isEmpty) return;
    final updated = state!.members.map((m) {
      if (m.fingerprint.startsWith('manual:') && m.ip == memberIp) {
        return m.copyWith(fingerprint: realFingerprint);
      }
      return m;
    }).toList();
    state = state!.copyWith(members: updated);
  }

  /// Whether the room is ready (at least 1 accepted member).
  bool get isRoomActive {
    if (state == null) return false;
    return state!.members.any((m) => m.status == MemberStatus.accepted);
  }

  Future<String> _getLocalIp({String? preferredPeerIp}) =>
      resolveLocalIp(preferredPeerIp: preferredPeerIp);

  String? _preferredPeerIpForSync() {
    if (state == null) return null;
    final accepted = state!.members
        .where((m) => m.status == MemberStatus.accepted)
        .toList();
    if (accepted.isNotEmpty) return accepted.first.ip;
    if (state!.members.isNotEmpty) return state!.members.first.ip;
    return null;
  }

  Future<String> _resolveHostIpForSync() async {
    final preferredPeerIp = _preferredPeerIpForSync();
    try {
      return await _getLocalIp(preferredPeerIp: preferredPeerIp);
    } catch (_) {
      return '127.0.0.1';
    }
  }

  Future<void> _sendInvite(
    RoomMember member,
    String roomId,
    String alias,
    String fingerprint,
    String hostIp,
    int hostPort,
  ) async {
    try {
      await _client.post(
        'http://${member.ip}:${member.port}/api/takeit/v1/room/invite',
        data: {
          'roomId': roomId,
          'hostAlias': alias,
          'hostFingerprint': fingerprint,
          'hostIp': hostIp,
          'hostPort': hostPort,
        },
      );

      // Schedule timeout — if member is still pending, auto-decline.
      Timer(_inviteTimeout, () {
        if (mounted) _expireInviteIfPending(roomId, member);
      });
    } catch (e) {
      debugPrint('Failed to invite ${member.alias}: $e');
      if (mounted) _handleInviteFailure(member);
    }
  }

  void _handleInviteFailure(RoomMember member) {
    if (state != null) {
      _updateMemberStatus(member.fingerprint, MemberStatus.declined);
    } else {
      final pending = _ref.read(pendingRoomProvider);
      if (pending != null) {
        final remaining = pending.members
            .where((m) => m.fingerprint != member.fingerprint)
            .toList();
        if (remaining.isEmpty) {
          _ref.read(pendingRoomProvider.notifier).state = null;
        } else {
          _ref.read(pendingRoomProvider.notifier).state = _PendingRoom(
            roomId: pending.roomId,
            hostFingerprint: pending.hostFingerprint,
            members: remaining,
          );
        }
      }
    }
  }

  void _expireInviteIfPending(String roomId, RoomMember member) {
    // Only expire if this is still the same pending invite.
    final room = state;
    if (room != null && room.id == roomId) {
      final current = room.members.firstWhere(
        (m) => m.fingerprint == member.fingerprint,
        orElse: () => member,
      );
      if (current.status == MemberStatus.pending) {
        debugPrint('Invite to ${member.alias} timed out');
        _updateMemberStatus(member.fingerprint, MemberStatus.declined);
      }
      return;
    }
    final pending = _ref.read(pendingRoomProvider);
    if (pending != null && pending.roomId == roomId) {
      final isStillPending = pending.members.any(
        (m) =>
            m.fingerprint == member.fingerprint &&
            m.status == MemberStatus.pending,
      );
      if (isStillPending) {
        debugPrint('Pending invite to ${member.alias} timed out');
        _handleInviteFailure(member);
      }
    }
  }

  Future<shelf.Response> _handleAccept(shelf.Request request) async {
    final body = jsonDecode(await request.readAsString());
    final fingerprint = body['fingerprint'] as String?;
    if (fingerprint == null) {
      return shelf.Response.badRequest(body: 'Missing fingerprint');
    }
    final memberAlias = body['alias'] as String? ?? '';
    final memberIp = request.headers['x-real-ip'] ?? '';
    final memberPort = body['port'] as int? ?? kDefaultPort;
    final memberDeviceType = body['deviceType'] as String? ?? 'unknown';

    // Only honour accepts for the room we are hosting right now — a late
    // accept for an expired invite must not join (or create) another room.
    if (!isHost || body['roomId'] != _hostedRoomId) {
      return shelf.Response.notFound(
        jsonEncode({'error': 'room_not_found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    final invited = state?.members ?? _ref.read(pendingRoomProvider)!.members;
    final isInvited = invited.any(
      (m) =>
          m.fingerprint == fingerprint ||
          (m.fingerprint.startsWith('manual:') &&
              memberIp.isNotEmpty &&
              m.ip == memberIp),
    );
    if (!isInvited) {
      return shelf.Response.forbidden(
        jsonEncode({'error': 'not_invited'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (state != null) {
      // Manual invite: pending member key is `manual:$ip`, replace it now
      // that we know the accepter's real fingerprint.
      _replaceManualPlaceholderInRoom(memberIp, fingerprint);
      _updateMemberInfo(
        fingerprint,
        MemberStatus.accepted,
        ip: memberIp,
        alias: memberAlias,
        port: memberPort,
        deviceType: memberDeviceType,
      );
    } else {
      // First accept — create the room from pending data
      final pending = _ref.read(pendingRoomProvider);
      if (pending != null) {
        final acceptedMembers = pending.members.map((m) {
          final manualMatch =
              m.fingerprint.startsWith('manual:') &&
              memberIp.isNotEmpty &&
              m.ip == memberIp;
          if (m.fingerprint == fingerprint) {
            return m.copyWith(
              status: MemberStatus.accepted,
              ip: memberIp.isNotEmpty ? memberIp : m.ip,
              alias: memberAlias.isNotEmpty ? memberAlias : m.alias,
            );
          }
          if (manualMatch) {
            // Replace placeholder fingerprint with the real one and fill in
            // alias/port/deviceType we didn't know at invite time.
            return m.copyWith(
              fingerprint: fingerprint,
              status: MemberStatus.accepted,
              ip: memberIp,
              alias: memberAlias.isNotEmpty ? memberAlias : m.alias,
              port: memberPort,
              deviceType: memberDeviceType.isNotEmpty
                  ? memberDeviceType
                  : m.deviceType,
            );
          }
          return m;
        }).toList();

        state = Room(
          id: pending.roomId,
          hostFingerprint: pending.hostFingerprint,
          members: acceptedMembers,
          createdAt: DateTime.now(),
        );
        _ref.read(pendingRoomProvider.notifier).state = null;
      }
    }

    _broadcastMemberSync();

    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Id of the room this device hosts — active or still waiting for its
  /// first accept — or null.
  String? get _hostedRoomId {
    if (!isHost) return null;
    return state?.id ?? _ref.read(pendingRoomProvider)?.roomId;
  }

  Future<shelf.Response> _handleLeave(shelf.Request request) async {
    final body = jsonDecode(await request.readAsString());
    final fingerprint = body['fingerprint'] as String?;
    final roomId = body['roomId'] as String?;

    if (fingerprint == null || roomId == null) {
      return shelf.Response.badRequest(body: 'Missing required fields');
    }

    if (state == null || state!.id != roomId) {
      return shelf.Response.notFound('');
    }

    if (fingerprint == state!.hostFingerprint) {
      _dissolveRoom();
    } else {
      // Remove the member (they intentionally left, not just disconnected)
      _updateMemberStatus(fingerprint, MemberStatus.declined);
      _broadcastMemberSync();
    }

    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  void _updateMemberInfo(
    String fingerprint,
    MemberStatus status, {
    String? ip,
    String? alias,
    int? port,
    String? deviceType,
  }) {
    if (state == null) return;
    final updated = state!.members.map((m) {
      if (m.fingerprint == fingerprint) {
        return m.copyWith(
          status: status,
          ip: ip != null && ip.isNotEmpty ? ip : m.ip,
          alias: alias != null && alias.isNotEmpty ? alias : m.alias,
          port: port ?? m.port,
          deviceType: deviceType ?? m.deviceType,
        );
      }
      return m;
    }).toList();
    state = state!.copyWith(members: updated);
  }

  /// Host sends the full member list + host info to all accepted members.
  /// Each member receives the complete picture so they can communicate directly.
  Future<void> _broadcastMemberSync() async {
    if (state == null || !isHost) return;

    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);
    final deviceType = _ref.read(deviceTypeProvider);
    final hostIp = await _resolveHostIpForSync();
    if (!mounted || state == null) return;

    final allMembers = <Map<String, dynamic>>[
      {
        'fingerprint': fingerprint,
        'alias': alias,
        'ip': hostIp,
        'port': _ownPort,
        'deviceType': deviceType,
        'isHost': true,
      },
      ...state!.members.map(
        (m) => {
          'fingerprint': m.fingerprint,
          'alias': m.alias,
          'ip': m.ip,
          'port': m.port,
          'deviceType': m.deviceType,
          'isHost': false,
          'status': m.status.name,
        },
      ),
    ];

    final payload = {
      'roomId': state!.id,
      'seq': ++_syncSeq,
      'members': allMembers,
    };

    for (final member in state!.members) {
      if (member.status != MemberStatus.accepted) continue;
      try {
        await _client.post(
          'http://${member.ip}:${member.port}/api/takeit/v1/room/sync',
          data: payload,
        );
      } catch (e) {
        debugPrint('Failed to sync member list to ${member.alias}: $e');
      }
    }
  }

  /// Non-host members receive the full member list from host.
  Future<shelf.Response> _handleSync(shelf.Request request) async {
    // Sync rewrites our entire member list — only accept it from a device
    // already in our room (in practice, the host).
    final current = state;
    if (current == null ||
        !isFromAllowedIp(request, current.members.map((m) => m.ip))) {
      return shelf.Response.forbidden(
        jsonEncode({'error': 'not_a_member'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final body = jsonDecode(await request.readAsString());
    final roomId = body['roomId'] as String?;
    final membersList = body['members'] as List<dynamic>?;

    if (roomId == null || membersList == null) {
      return shelf.Response.badRequest(body: 'Missing required fields');
    }

    if (current.id != roomId) {
      return shelf.Response.notFound('');
    }

    // Syncs are sent one member at a time, so an older roster can overtake a
    // newer one — never let it roll the member list back.
    final seq = body['seq'] as int?;
    if (seq != null) {
      if (seq <= (_lastSyncSeq[roomId] ?? -1)) {
        return shelf.Response.ok(
          jsonEncode({'status': 'stale'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      _lastSyncSeq[roomId] = seq;
    }

    // The host's self-reported IP is a guess (it can pick a VPN or virtual
    // adapter); the address this sync arrived from is reachable by definition.
    final senderIp = remoteIpOf(request);

    final myFingerprint = _ref.read(fingerprintProvider);

    // Rebuild members list: everyone except myself
    final updatedMembers = <RoomMember>[];
    for (final m in membersList) {
      final fp = m['fingerprint'] as String?;
      if (fp == null || fp == myFingerprint) continue;

      final alias = m['alias'] as String? ?? '';
      final ip = m['isHost'] == true && senderIp != null
          ? senderIp
          : m['ip'] as String? ?? '';
      final port = m['port'] as int? ?? kDefaultPort;
      final status = m['status'] as String?;
      updatedMembers.add(
        RoomMember(
          fingerprint: fp,
          alias: alias,
          ip: ip,
          port: port,
          deviceType: m['deviceType'] as String? ?? 'unknown',
          status: status == 'offline'
              ? MemberStatus.offline
              : status == 'pending'
              ? MemberStatus.pending
              : MemberStatus.accepted,
        ),
      );
    }

    state = state!.copyWith(members: updatedMembers);

    // Auto-dissolve if I'm the only active participant left after sync.
    final hasAccepted = updatedMembers.any(
      (m) => m.status == MemberStatus.accepted,
    );
    final hasPending = updatedMembers.any(
      (m) => m.status == MemberStatus.pending,
    );
    if (!hasAccepted && !hasPending) {
      debugPrint('Sync shows all others gone — dissolving room');
      _dissolveRoom();
    }

    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Simple ping endpoint — returns OK if alive + current room ID.
  Future<shelf.Response> _handlePing(shelf.Request request) async {
    return shelf.Response.ok(
      jsonEncode({'status': 'ok', 'roomId': state?.id}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  void _updateMemberStatus(String fingerprint, MemberStatus status) {
    if (state == null) return;

    List<RoomMember> updated;
    if (status == MemberStatus.declined) {
      // Remove declined members from the list
      updated = state!.members
          .where((m) => m.fingerprint != fingerprint)
          .toList();
    } else {
      updated = state!.members.map((m) {
        if (m.fingerprint == fingerprint) {
          return m.copyWith(status: status);
        }
        return m;
      }).toList();
    }

    state = state!.copyWith(members: updated);

    // Dissolve when nobody else is left to talk to: every other member has
    // left, declined or gone offline, and no invite is still pending.
    final hasAccepted = updated.any((m) => m.status == MemberStatus.accepted);
    final hasPending = updated.any((m) => m.status == MemberStatus.pending);
    if (!hasAccepted && !hasPending) {
      debugPrint('No other active members — dissolving room');
      _dissolveRoom();
    }
  }

  Future<void> acceptInvite(Map<String, dynamic> invite) async {
    _removeInviteFromQueue(invite);

    // Leave existing room first so peers get notified cleanly.
    if (state != null) {
      await leaveRoom();
    }

    final roomId = invite['roomId'] as String;
    final hostAlias = invite['hostAlias'] as String;
    final hostFingerprint = invite['hostFingerprint'] as String;
    final hostIp = invite['hostIp'] as String;
    final hostPort = invite['hostPort'] as int;
    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);
    final deviceType = _ref.read(deviceTypeProvider);

    // Start with just the host in members — sync will fill in the rest
    state = Room(
      id: roomId,
      hostFingerprint: hostFingerprint,
      members: [
        RoomMember(
          fingerprint: hostFingerprint,
          alias: hostAlias,
          ip: hostIp,
          port: hostPort,
          deviceType: 'unknown',
          status: MemberStatus.accepted,
        ),
      ],
      createdAt: DateTime.now(),
    );

    try {
      await _client.post(
        'http://$hostIp:$hostPort/api/takeit/v1/room/accept',
        data: {
          'roomId': roomId,
          'fingerprint': fingerprint,
          'alias': alias,
          'port': _ownPort,
          'deviceType': deviceType,
        },
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      // The host answered but refused (invite expired / room gone) — don't
      // sit in a room that only exists on this side. Plain network errors
      // are left to the connection monitor.
      if (status != null && status >= 400 && status < 500) {
        debugPrint('Host rejected accept ($status) — leaving room');
        if (state?.id == roomId) _dissolveRoom();
      } else {
        debugPrint('Failed to send accept: $e');
      }
    }
  }

  void _removeInviteFromQueue(Map<String, dynamic> invite) {
    final current = _ref.read(roomInvitesProvider);
    _ref.read(roomInvitesProvider.notifier).state = current
        .where((i) => i['roomId'] != invite['roomId'])
        .toList();
  }

  Future<void> declineInvite(Map<String, dynamic> invite) async {
    _removeInviteFromQueue(invite);
    final hostIp = invite['hostIp'] as String?;
    final hostPort = invite['hostPort'] as int?;
    final fingerprint = _ref.read(fingerprintProvider);
    if (hostIp != null && hostPort != null) {
      try {
        await _client.post(
          'http://$hostIp:$hostPort/api/takeit/v1/room/decline',
          data: {'roomId': invite['roomId'], 'fingerprint': fingerprint},
        );
      } catch (_) {}
    }
  }

  Future<shelf.Response> _handleDecline(shelf.Request request) async {
    final body = jsonDecode(await request.readAsString());
    final fingerprint = body['fingerprint'] as String?;
    if (fingerprint == null) {
      return shelf.Response.badRequest(body: 'Missing fingerprint');
    }
    // A decline for an older invite must not remove the same device from
    // the room we host now.
    if (body['roomId'] != _hostedRoomId) {
      return shelf.Response.notFound(
        jsonEncode({'error': 'room_not_found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (state != null) {
      // Room exists — remove declined member
      _updateMemberStatus(fingerprint, MemberStatus.declined);
    } else {
      // Room not created yet — remove from pending
      final pending = _ref.read(pendingRoomProvider);
      if (pending != null) {
        final remaining = pending.members
            .where((m) => m.fingerprint != fingerprint)
            .toList();
        if (remaining.isEmpty ||
            !remaining.any((m) => m.status == MemberStatus.pending)) {
          // Everyone declined or failed — clear pending
          _ref.read(pendingRoomProvider.notifier).state = null;
        } else {
          _ref.read(pendingRoomProvider.notifier).state = _PendingRoom(
            roomId: pending.roomId,
            hostFingerprint: pending.hostFingerprint,
            members: remaining,
          );
        }
      }
    }

    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<void> leaveRoom() async {
    if (state == null && _ref.read(pendingRoomProvider) == null) return;

    final room = state;
    final fingerprint = _ref.read(fingerprintProvider);

    if (room != null) {
      if (isHost) {
        final notifications = <Future<void>>[];
        for (final member in room.members) {
          if (member.status != MemberStatus.accepted) continue;
          notifications.add(
            Future(() async {
              try {
                await _client.post(
                  'http://${member.ip}:${member.port}/api/takeit/v1/room/leave',
                  data: {'roomId': room.id, 'fingerprint': fingerprint},
                );
              } catch (_) {}
            }),
          );
        }
        // Send in parallel, don't wait forever
        await Future.wait(
          notifications,
        ).timeout(const Duration(seconds: 3), onTimeout: () => []);
      } else {
        final host = room.members
            .where((m) => m.fingerprint == room.hostFingerprint)
            .firstOrNull;
        if (host != null) {
          try {
            await _client.post(
              'http://${host.ip}:${host.port}/api/takeit/v1/room/leave',
              data: {'roomId': room.id, 'fingerprint': fingerprint},
            );
          } catch (_) {}
        }
      }
    }

    if (!mounted) return;
    _ref.read(pendingRoomProvider.notifier).state = null;
    _dissolveRoom();
  }

  int get onlineMemberCount {
    if (state == null) return 0;
    return state!.members
        .where((m) => m.status == MemberStatus.accepted)
        .length;
  }

  bool get hasAcceptedMembers => onlineMemberCount > 0;
}
