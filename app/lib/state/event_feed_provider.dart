import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../protocol/message.dart';
import 'connection_provider.dart';

class TactEventItem {
  final String eventType;
  final double timestamp;
  final String source;
  final String title;
  final String message;
  final String severity;
  final List<String> actions;

  const TactEventItem({
    required this.eventType,
    required this.timestamp,
    required this.source,
    required this.title,
    required this.message,
    required this.severity,
    required this.actions,
  });

  factory TactEventItem.fromJson(Map<String, dynamic> json) {
    return TactEventItem(
      eventType: json['event_type'] as String? ?? 'unknown',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0,
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      actions:
          (json['actions'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// Newest-first feed of developer events, capped at 100 entries.
/// Mirrors the web client's event log (`client/index.html`).
final eventFeedProvider =
    StateNotifierProvider<EventFeedNotifier, List<TactEventItem>>((ref) {
  final notifier = EventFeedNotifier();
  final sub = ref.watch(tactClientProvider).messages.listen((msg) {
    if (msg is TactEvent) notifier.add(msg.payload);
  });
  ref.onDispose(sub.cancel);
  return notifier;
});

class EventFeedNotifier extends StateNotifier<List<TactEventItem>> {
  EventFeedNotifier() : super(const []);

  void add(Map<String, dynamic> payload) {
    final item = TactEventItem.fromJson(payload);
    state = [item, ...state].take(100).toList();
  }
}