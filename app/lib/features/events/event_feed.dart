import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/event_feed_provider.dart';

/// Developer event feed (build/test/docker/git/system events pushed by the
/// agent's EventBus). Port of the web client's Event Log tab.
class EventFeed extends ConsumerWidget {
  const EventFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventFeedProvider);

    if (events.isEmpty) {
      return const Center(
        child: Text('No events yet'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) => _EventCard(event: events[index]),
    );
  }
}

class _EventCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = _color(context);
    final time = DateTime.fromMillisecondsSinceEpoch(
      (event.timestamp * 1000).round(),
    ).toLocal();
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Card(
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
                children: event.actions
                    .map(
                      (a) => Chip(
                        label: Text(a, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}