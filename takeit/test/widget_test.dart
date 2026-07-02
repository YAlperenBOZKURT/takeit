import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takeit/core/l10n/app_strings.dart';
import 'package:takeit/features/nickname/presentation/pages/nickname_page.dart';
import 'package:takeit/main.dart';

/// Wraps a page with the localization + Material scaffolding it needs, so we
/// can test screens in isolation without booting the whole app (which performs
/// network, discovery, and server side-effects on startup).
Widget _harness(Widget child, {String nickname = ''}) {
  return ProviderScope(
    overrides: [initialNicknameProvider.overrideWithValue(nickname)],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  group('NicknamePage', () {
    testWidgets('renders the nickname entry UI', (tester) async {
      await tester.pumpWidget(_harness(const NicknamePage()));
      await tester.pumpAndSettle();

      expect(find.byType(NicknamePage), findsOneWidget);
      // A text field to type a nickname, and a button to continue.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('typing updates the field', (tester) async {
      await tester.pumpWidget(_harness(const NicknamePage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'CoolWombat');
      await tester.pump();

      expect(find.text('CoolWombat'), findsOneWidget);
    });
  });
}
