import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/telemetry_provider.dart';
import 'action_button.dart';

const _knownSystemActions =
    <String, (String, IconData)>{
  'system.lock_screen': (
    'Lock Screen',
    Icons.lock,
  ),
  'system.mute': (
    'Mute',
    Icons.volume_off,
  ),
  'system.open_terminal': (
    'Terminal',
    Icons.terminal,
  ),
  'system.screenshot': (
    'Screenshot',
    Icons.screenshot,
  ),
  'system.volume_down': (
    'Volume Down',
    Icons.volume_down,
  ),
  'system.volume_up': (
    'Volume Up',
    Icons.volume_up,
  ),
};

class ActionsGrid extends ConsumerWidget {
  const ActionsGrid({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final state =
        ref.watch(tactStateProvider);

    final actionIds =
        (state?['actions'] as List?)
                ?.whereType<String>()
                .toList() ??
            const <String>[];

    final available =
        _knownSystemActions.keys
            .where(actionIds.contains)
            .toList();

    if (available.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: available.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final id = available[index];
        final config =
            _knownSystemActions[id]!;

        return ActionButton(
          actionId: id,
          label: config.$1,
          icon: config.$2,
        );
      },
    );
  }
}