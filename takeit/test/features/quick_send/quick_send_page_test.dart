import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/l10n/app_strings.dart';
import 'package:takeit/features/quick_send/presentation/pages/quick_send_page.dart';

/// FilePicker fake with a controllable completer, so tests can hold the
/// picker open (loading state) and finish it on demand.
class _FakeFilePicker extends FilePicker {
  Completer<FilePickerResult?>? completer;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) {
    completer = Completer<FilePickerResult?>();
    return completer!.future;
  }
}

Widget _harness(Widget child) {
  return ProviderScope(
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
  late _FakeFilePicker picker;
  late Directory tempDir;

  // testWidgets bodies (and their setUp/tearDown) run in a FakeAsync zone
  // where real async I/O never completes — all file work here must be sync.
  setUp(() {
    picker = _FakeFilePicker();
    FilePicker.platform = picker;
    tempDir = Directory.systemTemp.createTempSync('takeit_page_test');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  FilePickerResult makeResult(List<String> names) {
    final files = <PlatformFile>[];
    for (final name in names) {
      // Real files on disk — the page verifies existence and reads sizes.
      final f = File('${tempDir.path}/$name');
      f.writeAsBytesSync(List.filled(64, 1));
      files.add(PlatformFile(path: f.path, name: name, size: 64));
    }
    return FilePickerResult(files);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(_harness(const QuickSendPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a loading state while the picker is preparing files',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Add File'));
    await tester.pump();

    // Loading: spinner + label swap, and the action buttons are disabled.
    expect(find.text('Preparing files…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final addButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(addButton.onPressed, isNull);

    picker.completer!.complete(makeResult(['report.pdf', 'photo.png']));
    await tester.pumpAndSettle();

    // Loading cleared, both files listed.
    expect(find.text('Preparing files…'), findsNothing);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
  });

  testWidgets('cancelled pick clears the loading state and adds nothing',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Add File'));
    await tester.pump();
    expect(find.text('Preparing files…'), findsOneWidget);

    picker.completer!.complete(null); // user dismissed the OS dialog
    await tester.pumpAndSettle();

    expect(find.text('Preparing files…'), findsNothing);
    expect(find.text('Add File'), findsOneWidget);
    expect(find.text('Clear All'), findsNothing);
  });

  testWidgets('Clear All appears with files and empties the list',
      (tester) async {
    await pumpPage(tester);
    expect(find.text('Clear All'), findsNothing);

    await tester.tap(find.text('Add File'));
    await tester.pump();
    picker.completer!.complete(makeResult(['a.txt', 'b.txt']));
    await tester.pumpAndSettle();

    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('Clear All'), findsOneWidget);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(find.text('a.txt'), findsNothing);
    expect(find.text('b.txt'), findsNothing);
    expect(find.text('Clear All'), findsNothing);
    // Back to the empty drop zone.
    expect(find.text('Drop files here'), findsOneWidget);
  });
}
