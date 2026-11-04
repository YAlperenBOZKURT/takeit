// Two-peer room tests: each peer is a real AppHttpServer + RoomNotifier on
// loopback, talking to the other over HTTP exactly as on a LAN.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/network/http_server.dart';
import 'package:takeit/features/discovery/domain/entities/device.dart';
import 'package:takeit/features/discovery/presentation/providers/device_actions_provider.dart';
import 'package:takeit/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:takeit/features/room/domain/entities/room.dart';
import 'package:takeit/features/room/domain/entities/room_member.dart';
import 'package:takeit/features/room/presentation/providers/room_provider.dart';
import 'package:takeit/main.dart';

class _Peer {
  final String fingerprint;
  final String alias;
  final AppHttpServer server;
  final ProviderContainer container;

  _Peer._(this.fingerprint, this.alias, this.server, this.container);

  static Future<_Peer> start(
    String fingerprint, {
    Duration connectionCheckInterval = const Duration(milliseconds: 100),
    Duration inviteTimeout = kInviteTimeout,
  }) async {
    final server = AppHttpServer(port: 0);
    await server.start();
    final container = ProviderContainer(
      overrides: [
        httpServerProvider.overrideWithValue(server),
        fingerprintProvider.overrideWithValue(fingerprint),
        initialNicknameProvider.overrideWithValue(fingerprint),
        roomProvider.overrideWith(
          (ref) => RoomNotifier(
            ref,
            connectionCheckInterval: connectionCheckInterval,
            inviteTimeout: inviteTimeout,
          ),
        ),
      ],
    );
    container.read(roomProvider.notifier);
    return _Peer._(fingerprint, fingerprint, server, container);
  }

  int get port => server.boundPort!;
  Room? get room => container.read(roomProvider);
  RoomNotifier get notifier => container.read(roomProvider.notifier);
  List<Map<String, dynamic>> get invites => container.read(roomInvitesProvider);

  Device get asDevice => Device(
    fingerprint: fingerprint,
    alias: alias,
    deviceType: 'desktop',
    ip: '127.0.0.1',
    port: port,
    lastSeen: DateTime.now(),
  );

  Future<void> dispose() async {
    container.dispose();
    await server.stop();
  }
}

/// Polls [condition] until it holds or [timeout] passes.
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(reason ?? 'condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// POSTs [body] as JSON to [peer] and returns the status code.
Future<int> _post(_Peer peer, String path, Map<String, dynamic> body) async {
  final client = HttpClient();
  final req = await client.postUrl(
    Uri.parse('http://127.0.0.1:${peer.port}/api/takeit/v1$path'),
  );
  req.headers.contentType = ContentType.json;
  req.write(jsonEncode(body));
  final res = await req.close();
  await res.drain<void>();
  client.close();
  return res.statusCode;
}

/// GETs [path] from [peer] and returns the decoded JSON body.
Future<Map<String, dynamic>> _getJson(_Peer peer, String path) async {
  final client = HttpClient();
  final req = await client.getUrl(
    Uri.parse('http://127.0.0.1:${peer.port}/api/takeit/v1$path'),
  );
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  client.close();
  return jsonDecode(body) as Map<String, dynamic>;
}

bool _hasMember(_Peer peer, String fingerprint) =>
    peer.room?.members.any((m) => m.fingerprint == fingerprint) ?? false;

bool _hasAccepted(_Peer peer, String fingerprint) =>
    peer.room?.members.any(
      (m) => m.fingerprint == fingerprint && m.status == MemberStatus.accepted,
    ) ??
    false;

/// Rooms with more than two people, and the ways they end.
void _lifecycleTests() {
  late _Peer host;
  late _Peer a;
  late _Peer b;

  setUp(() async {
    host = await _Peer.start('host-fp');
    a = await _Peer.start('a-fp');
    b = await _Peer.start('b-fp');
  });

  tearDown(() async {
    await host.dispose();
    await a.dispose();
    await b.dispose();
  });

  Future<void> join(_Peer guest) async {
    await eventually(() => guest.invites.isNotEmpty, reason: 'invite');
    await guest.notifier.acceptInvite(guest.invites.last);
    await eventually(
      () => _hasAccepted(host, guest.fingerprint),
      reason: 'host sees ${guest.fingerprint} accepted',
    );
  }

  /// Host, a and b all in one room, every roster complete.
  Future<void> formRoomOfThree() async {
    await host.notifier.createRoom([a.asDevice, b.asDevice]);
    await join(a);
    await join(b);
    await eventually(
      () => _hasAccepted(a, b.fingerprint) && _hasAccepted(b, a.fingerprint),
      reason: 'members see each other',
    );
  }

  test('leaving ends the room locally right away', () async {
    await formRoomOfThree();

    final leaving = a.notifier.leaveRoom();
    expect(a.room, isNull, reason: 'not only after the peers answered');
    await leaving;
  });

  test('a member leaving is dropped from the other members too', () async {
    await formRoomOfThree();

    await a.notifier.leaveRoom();

    await eventually(
      () => !_hasMember(b, a.fingerprint) && !_hasMember(host, a.fingerprint),
      reason: 'roster without a',
    );
    expect(b.room, isNotNull, reason: 'host and b are still together');
    expect(host.room, isNotNull);
  });

  test('two members leaving at once dissolves the room everywhere', () async {
    await formRoomOfThree();

    await Future.wait([a.notifier.leaveRoom(), b.notifier.leaveRoom()]);

    await eventually(() => host.room == null, reason: 'host alone → ends');
    expect(a.room, isNull);
    expect(b.room, isNull);
  });

  test('host and a member leaving at once dissolves the room '
      'everywhere', () async {
    await formRoomOfThree();

    await Future.wait([host.notifier.leaveRoom(), a.notifier.leaveRoom()]);

    await eventually(() => b.room == null, reason: 'b learns the host left');
    expect(host.room, isNull);
    expect(a.room, isNull);
  });

  test('an invitee declining is dropped from the members\' rosters', () async {
    await host.notifier.createRoom([a.asDevice, b.asDevice]);
    await join(a);
    await eventually(() => _hasMember(a, b.fingerprint), reason: 'b pending');
    await eventually(() => b.invites.isNotEmpty);

    await b.notifier.declineInvite(b.invites.last);

    await eventually(
      () => !_hasMember(a, b.fingerprint),
      reason: 'a must not keep showing b as pending',
    );
    expect(host.room, isNotNull);
  });

  test('host leaving withdraws invites that are still unanswered', () async {
    await host.notifier.createRoom([a.asDevice, b.asDevice]);
    await join(a);
    await eventually(() => b.invites.isNotEmpty);

    await host.notifier.leaveRoom();

    await eventually(() => b.invites.isEmpty, reason: 'invite withdrawn');
    await eventually(() => a.room == null, reason: 'member told');
  });

  test('abandoning a room before anyone accepted withdraws its '
      'invites', () async {
    await host.notifier.createRoom([a.asDevice, b.asDevice]);
    await eventually(() => a.invites.isNotEmpty && b.invites.isNotEmpty);

    await host.notifier.leaveRoom();

    await eventually(
      () => a.invites.isEmpty && b.invites.isEmpty,
      reason: 'both invites withdrawn',
    );
  });

  test('creating a new room withdraws the previous room\'s invites', () async {
    await host.notifier.createRoom([a.asDevice]);
    await eventually(() => a.invites.isNotEmpty);

    await host.notifier.createRoom([b.asDevice]);

    await eventually(() => b.invites.isNotEmpty, reason: 'new invite');
    await eventually(() => a.invites.isEmpty, reason: 'old invite withdrawn');
  });

  test('only the inviting host can withdraw an invite', () async {
    await host.notifier.createRoom([a.asDevice]);
    await eventually(() => a.invites.isNotEmpty);
    final roomId = a.invites.last['roomId'] as String;

    final status = await _post(a, '/room/leave', {
      'roomId': roomId,
      'fingerprint': b.fingerprint,
    });

    expect(status, 404);
    expect(a.invites, hasLength(1));
  });

  test('ping reports a room still waiting for its first accept to its '
      'invitees', () async {
    // An invitee that has just accepted already sits in the room; a ping
    // answered with "no room" made it leave again.
    await host.notifier.createRoom([a.asDevice]);
    await eventually(() => a.invites.isNotEmpty);

    final ping = await _getJson(host, '/ping');

    expect(ping['roomId'], a.invites.last['roomId']);
  });
}

void main() {
  group('two peers', _twoPeerTests);
  group('room lifecycle', _lifecycleTests);
}

void _twoPeerTests() {
  late _Peer host;
  late _Peer guest;

  setUp(() async {
    host = await _Peer.start('host-fp');
    guest = await _Peer.start('guest-fp');
  });

  tearDown(() async {
    await host.dispose();
    await guest.dispose();
  });

  /// Host invites guest, guest accepts; returns once both see the room.
  Future<void> formRoom() async {
    await host.notifier.createRoom([guest.asDevice]);
    await eventually(() => guest.invites.isNotEmpty, reason: 'invite');
    await guest.notifier.acceptInvite(guest.invites.last);
    await eventually(
      () =>
          host.room?.members.any(
            (m) =>
                m.fingerprint == guest.fingerprint &&
                m.status == MemberStatus.accepted,
          ) ??
          false,
      reason: 'host sees guest accepted',
    );
    expect(guest.room?.id, host.room!.id);
  }

  RoomMember? hostEntryOnGuest() => guest.room?.members
      .where((m) => m.fingerprint == host.fingerprint)
      .firstOrNull;

  test('guest records the host at the address its sync came from', () async {
    await formRoom();

    // The host's roster sync carries its real deviceType ('desktop'); the
    // invite-time placeholder says 'unknown'.
    await eventually(
      () => hostEntryOnGuest()?.deviceType == 'desktop',
      reason: 'host roster sync applied',
    );
    expect(
      hostEntryOnGuest()!.ip,
      '127.0.0.1',
      reason: 'self-reported host IP must not replace the observed one',
    );
  });

  test('connection monitor still works for a room formed after another one '
      'dissolved', () async {
    await formRoom();
    await guest.notifier.leaveRoom();
    await eventually(() => host.room == null, reason: 'first room dissolves');

    await formRoom();
    await guest.server.stop();

    // Two failed pings are needed; on Windows a refused loopback connect
    // takes ~2s each, so allow well beyond that.
    await eventually(
      () => host.room == null,
      timeout: const Duration(seconds: 10),
      reason: 'host must notice the vanished guest and dissolve',
    );
  });

  test(
    'accept for another (expired) room is rejected and joins nothing',
    () async {
      await host.notifier.createRoom([guest.asDevice]);
      await eventually(() => guest.invites.isNotEmpty);

      final status = await _post(host, '/room/accept', {
        'roomId': 'expired-room-id',
        'fingerprint': guest.fingerprint,
        'alias': guest.alias,
        'port': guest.port,
      });

      expect(status, 404);
      expect(host.room, isNull, reason: 'no room may be created from it');
    },
  );

  test('guest leaves a room whose host rejects its accept', () async {
    // Invite that looks valid but the host has no such room.
    await guest.notifier.acceptInvite({
      'roomId': 'stale-room-id',
      'hostAlias': host.alias,
      'hostFingerprint': host.fingerprint,
      'hostIp': '127.0.0.1',
      'hostPort': host.port,
    });

    expect(guest.room, isNull);
  });

  test('accept from a device that was never invited is rejected', () async {
    await host.notifier.createRoom([guest.asDevice]);
    await eventually(() => guest.invites.isNotEmpty);
    final roomId = guest.invites.last['roomId'] as String;

    final status = await _post(host, '/room/accept', {
      'roomId': roomId,
      'fingerprint': 'intruder-fp',
      'alias': 'Intruder',
    });

    expect(status, 403);
    expect(host.room, isNull);
  });

  test('decline for an old invite does not remove a current member', () async {
    await formRoom();

    final status = await _post(host, '/room/decline', {
      'roomId': 'old-room-id',
      'fingerprint': guest.fingerprint,
    });

    expect(status, 404);
    expect(
      host.room?.members.map((m) => m.fingerprint),
      contains(guest.fingerprint),
    );
  });

  test('invitee drops an invite once the invite timeout passes', () async {
    final shortGuest = await _Peer.start(
      'short-guest-fp',
      inviteTimeout: const Duration(milliseconds: 200),
    );
    addTearDown(shortGuest.dispose);

    await host.notifier.createRoom([shortGuest.asDevice]);
    await eventually(() => shortGuest.invites.isNotEmpty);

    await eventually(
      () => shortGuest.invites.isEmpty,
      timeout: const Duration(seconds: 1),
      reason: 'expired invite must leave the queue',
    );
  });

  test('invite without the required fields is rejected', () async {
    final status = await _post(guest, '/room/invite', {'hostAlias': 'x'});

    expect(status, 400);
    expect(guest.invites, isEmpty);
  });

  Map<String, dynamic> invite(String fp) => {
    'roomId': 'room-$fp',
    'hostAlias': fp,
    'hostFingerprint': fp,
    'hostPort': 1,
  };

  test('invites from a blocked device are refused', () async {
    guest.container
        .read(blockedDevicesProvider.notifier)
        .add(host.fingerprint, '127.0.0.1');

    final status = await _post(guest, '/room/invite', invite('fresh-fp'));

    expect(status, 403, reason: 'blocked by IP even under a new fingerprint');
    expect(guest.invites, isEmpty);
  });

  test('the invite queue is capped', () async {
    for (var i = 0; i < kMaxPendingInvites; i++) {
      expect(await _post(guest, '/room/invite', invite('fp-$i')), 200);
    }

    final status = await _post(guest, '/room/invite', invite('fp-extra'));

    expect(status, 429);
    expect(guest.invites, hasLength(kMaxPendingInvites));
  });

  test('a leave for a device that is not in the room is refused', () async {
    await formRoom();

    final status = await _post(host, '/room/leave', {
      'roomId': host.room!.id,
      'fingerprint': 'someone-else',
    });

    expect(status, 403);
    expect(host.room, isNotNull);
  });

  test('an older roster sync cannot roll back a newer one', () async {
    await formRoom();
    final roomId = guest.room!.id;
    Map<String, dynamic> member(String fp) => {
      'fingerprint': fp,
      'alias': fp,
      'ip': '127.0.0.1',
      'port': 1,
      'status': 'accepted',
    };
    final hostEntry = {
      'fingerprint': host.fingerprint,
      'alias': host.alias,
      'ip': '127.0.0.1',
      'port': host.port,
      'isHost': true,
    };

    await _post(guest, '/room/sync', {
      'roomId': roomId,
      'seq': 1000,
      'members': [hostEntry, member('third-fp')],
    });
    await _post(guest, '/room/sync', {
      'roomId': roomId,
      'seq': 999,
      'members': [hostEntry],
    });

    expect(guest.room!.members.map((m) => m.fingerprint), contains('third-fp'));
  });
}
