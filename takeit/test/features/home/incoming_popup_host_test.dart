import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/l10n/app_strings.dart';
import 'package:takeit/core/network/http_server.dart';
import 'package:takeit/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:takeit/features/home/presentation/pages/home_shell.dart';
import 'package:takeit/features/home/presentation/widgets/incoming_popup_host.dart';
import 'package:takeit/features/quick_send/presentation/providers/quick_send_provider.dart';
import 'package:takeit/features/quick_send/presentation/widgets/quick_text_popup.dart';
import 'package:takeit/features/room/presentation/pages/room_invite_sheet.dart';
import 'package:takeit/features/room/presentation/providers/room_provider.dart';
import 'package:takeit/main.dart';

/// An invite as it sits in the queue. No host address, so declining it
/// sends nothing over the network.
Map<String, dynamic> _invite(String host, {String? roomId}) => {
  'roomId': roomId ?? 'room-$host',
  'hostAlias': host,
  'hostFingerprint': '$host-fp',
  'hostPort': 1,
};

/// The popup host over an empty page, with a never-started server behind
/// the room provider.
Future<ProviderContainer> _pump(WidgetTester tester) async {
  // The scope owns the container, so it is disposed with the widget tree
  // (stopping the room provider's connection timer) before the test ends.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        httpServerProvider.overrideWithValue(AppHttpServer(port: 0)),
        fingerprintProvider.overrideWithValue('me-fp'),
        initialNicknameProvider.overrideWithValue('Me'),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const IncomingPopupHost(child: Scaffold(body: SizedBox())),
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void _setInvites(ProviderContainer c, List<Map<String, dynamic>> invites) =>
    c.read(roomInvitesProvider.notifier).state = invites;

Finder _inviteFrom(String host) =>
    find.textContaining('$host invites you to a room');

void main() {
  testWidgets('several invites open one sheet at a time', (tester) async {
    final c = await _pump(tester);

    _setInvites(c, [_invite('Alice'), _invite('Bob')]);
    await tester.pumpAndSettle();

    expect(find.byType(RoomInviteSheet), findsOneWidget);
    expect(_inviteFrom('Bob'), findsOneWidget, reason: 'newest first');
  });

  testWidgets('the next invite opens once the current one is answered — '
      'without waiting for another invite to arrive', (tester) async {
    final c = await _pump(tester);
    _setInvites(c, [_invite('Alice'), _invite('Bob')]);
    await tester.pumpAndSettle();

    // Accepting or declining takes the invite out of the queue first.
    _setInvites(c, [_invite('Alice')]);
    await tester.pumpAndSettle();

    expect(find.byType(RoomInviteSheet), findsOneWidget);
    expect(_inviteFrom('Alice'), findsOneWidget);
  });

  testWidgets('accepting switches to the Chat tab and still shows the '
      'remaining invites', (tester) async {
    final c = await _pump(tester);
    _setInvites(c, [_invite('Alice'), _invite('Bob')]);
    await tester.pumpAndSettle();

    // What Join does once the room switch is confirmed: the invite leaves
    // the queue (acceptInvite) and the sheet closes with `true`.
    final sheet = tester.element(find.byType(RoomInviteSheet));
    _setInvites(c, [_invite('Alice')]);
    Navigator.of(sheet).pop(true);
    await tester.pumpAndSettle();

    expect(c.read(homeTabProvider), 1);
    expect(_inviteFrom('Alice'), findsOneWidget);
  });

  testWidgets('swiping an invite away declines it instead of reopening it', (
    tester,
  ) async {
    final c = await _pump(tester);
    _setInvites(c, [_invite('Alice')]);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(RoomInviteSheet))).pop();
    await tester.pumpAndSettle();

    expect(c.read(roomInvitesProvider), isEmpty);
    expect(find.byType(RoomInviteSheet), findsNothing);
  });

  testWidgets('a newer invite from the same host replaces the open one', (
    tester,
  ) async {
    final c = await _pump(tester);
    _setInvites(c, [_invite('Alice', roomId: 'old-room')]);
    await tester.pumpAndSettle();

    _setInvites(c, [
      {..._invite('Alice', roomId: 'new-room'), 'hostAlias': 'Alice again'},
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(RoomInviteSheet), findsOneWidget);
    expect(_inviteFrom('Alice again'), findsOneWidget);
  });

  testWidgets('a quick text waits until the open invite is closed', (
    tester,
  ) async {
    final c = await _pump(tester);
    _setInvites(c, [_invite('Alice')]);
    await tester.pumpAndSettle();

    c.read(incomingQuickTextProvider.notifier).state = QuickTextMessage(
      senderId: 'bob-fp',
      senderAlias: 'Bob',
      content: 'hello',
      timestamp: DateTime(2026),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuickTextPopup), findsNothing);

    _setInvites(c, []);
    await tester.pumpAndSettle();

    expect(find.byType(RoomInviteSheet), findsNothing);
    expect(find.byType(QuickTextPopup), findsOneWidget);
  });
}
