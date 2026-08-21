import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/event_feed_provider.dart';
import '../../theme.dart';

/// Developer event feed (build/test/docker/git/system events pushed by the
/// agent's EventBus). Port of the web client's Event Log tab.
class EventFeed extends ConsumerWidget {
  const EventFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventFeedProvider);
    final dismissed = ref.watch(dismissedEventsProvider);
    final visible = events.where((e) => !dismissed.contains(_key(e))).toList();

    if (visible.isEmpty) {
      return const Center(child: Text('No events yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visible.length,
      itemBuilder: (context, index) => _EventCard(event: visible[index]),
    );
  }

  static String _key(TactEventItem e) => '${e.eventType}@${e.timestamp}';
}

class _EventCard extends ConsumerWidget {
  final TactEventItem event;
  const _EventCard({required this.event});

  Color _color(BuildContext context) {
    switch (event.severity) {
      case 'error':
        return Colors.red.shade700;
      case 'warning':
        return Colors.orange.shade800;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _color(context);
    final time =
        DateTime.fromMillisecondsSinceEpoch(
          (event.timestamp * 1000).round(),
        ).toLocal();
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    // Phase 3.7: swipe to dismiss marks the event read — the underlying
    // state it reported is untouched.
    return Dismissible(
      key: ValueKey(EventFeed._key(event)),
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        ref
            .read(dismissedEventsProvider.notifier)
            .update((set) => {...set, EventFeed._key(event)});
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check, color: AppTheme.success),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check, color: AppTheme.success),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 10, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(event.message, style: Theme.of(context).textTheme.bodySmall),
              if (event.actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      event.actions
                          .map(
                            (a) => Chip(
                              label: Text(
                                a,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
