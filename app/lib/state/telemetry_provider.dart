import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../protocol/message.dart';
import 'connection_provider.dart';

/// Latest full state snapshot — seeded by `init`, refreshed by `telemetry`.
final tactStateProvider =
StateNotifierProvider<TactStateNotifier, Map<String, dynamic>?>((ref) {
  final notifier = TactStateNotifier();
  final sub = ref.watch(tactClientProvider).messages.listen((msg) {
    if (msg is TactInit) notifier.update(msg.state);
    if (msg is TactTelemetry) notifier.update(msg.state);
  });
  ref.onDispose(sub.cancel);
  return notifier;
});

class TactStateNotifier extends StateNotifier<Map<String, dynamic>?> {
  TactStateNotifier() : super(null);

  /// When the current snapshot was received (stale-indicator input).
  DateTime? lastUpdated;

  void update(Map<String, dynamic> newState) {
    state = newState;
    lastUpdated = DateTime.now();
  }
}
