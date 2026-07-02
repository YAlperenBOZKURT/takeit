import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import 'quick_send_sheet.dart';

class QuickSendFab extends ConsumerWidget {
  const QuickSendFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);

    return FloatingActionButton(
      heroTag: 'quick_send_fab',
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const QuickSendSheet(),
        );
      },
      tooltip: s.quickSend,
      child: const Icon(Icons.send_rounded),
    );
  }
}
