import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../providers/session_transfers_provider.dart';
import 'session_transfers_sheet.dart';

class TransfersFab extends ConsumerWidget {
  const TransfersFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(sessionTransfersProvider);
    if (transfers.isEmpty) return const SizedBox.shrink();

    final activeCount = ref.watch(activeTransferCountProvider);
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return FloatingActionButton.extended(
      // No Hero: this FAB is rendered independently on multiple tabs that
      // all stay mounted at once (IndexedStack in HomeShell). A shared tag
      // makes the Navigator's Hero flight scan see duplicate tags the
      // instant any route transitions (e.g. the quick-send sheet closing),
      // which corrupts Material's ink-renderer GlobalKey and crashes.
      heroTag: null,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const SessionTransfersSheet(),
        );
      },
      tooltip: s.sessionTransfersTitle,
      icon: activeCount > 0
          ? Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                if (activeCount > 1)
                  Text(
                    '$activeCount',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            )
          : const Icon(Icons.swap_vert),
      label: Text('${transfers.length}'),
    );
  }
}
