import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../../theme.dart';
import '../../widgets/marquee_text.dart';
import '../actions/action_button.dart';

/// Media controls: MPRIS players (Spotify, browser media sessions, VLC, …)
/// controlled via the agent's `playerctl` integration.
class MediaTab extends ConsumerStatefulWidget {
  const MediaTab({super.key});

  @override
  ConsumerState<MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends ConsumerState<MediaTab> {
  String? _selectedPlayer;
  final Set<String> _busyActions = {};
  double? _systemVolume;
  bool _volumeDragging = false;
  double? _position;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _control(String action) async {
    setState(() => _busyActions.add(action));
    try {
      final client = ref.read(tactClientProvider);
      await client.sendAction(action, {'player': _selectedPlayer});
      HapticFeedback.lightImpact();
      // No manual refresh needed: the agent re-broadcasts a fresh snapshot
      // right after state-changing actions.
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busyActions.remove(action));
    }
  }

  Future<void> _setVolume(double value) async {
    setState(() {
      _systemVolume = value;
      _volumeDragging = false;
    });
    try {
      await ref.read(tactClientProvider).sendAction('system.volume', {
        'value': value.round(),
      });
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _seek(double position) async {
    try {
      await ref.read(tactClientProvider).sendAction('media.seek', {
        'player': _selectedPlayer,
        'position': position,
      });
      setState(() => _position = position);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      await ref.read(tactClientProvider).sendAction('system.open_url', {
        'url': url,
      });
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _openSpotify() async {
    try {
      final result = await ref
          .read(tactClientProvider)
          .sendAction('media.open_spotify', {});
      final inner = result is Map ? (result['result'] as Map?) ?? result : null;
      if (inner?['ok'] != true) {
        _snack('Spotify desktop not found — opening web player');
      }
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tactStateProvider);
    final media = (state?['media'] as Map?)?.cast<String, dynamic>();

    if (media == null || media['available'] != true) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media controls unavailable',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The agent needs playerctl (MPRIS) to control Spotify, '
                    'browser media, and other players.',
                  ),
                  const SizedBox(height: 4),
                  const Text('Install with: sudo apt install playerctl'),
                  const SizedBox(height: 16),
                  const ActionButton(
                    actionId: 'media.status',
                    label: 'Check Again',
                    icon: Icons.refresh,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final players =
        (media['players'] as List?)?.whereType<String>().toList() ?? <String>[];
    final details = (media['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final active = (media['active'] as Map?)?.cast<String, dynamic>();
    final activePlayer = active?['player'] as String?;

    _selectedPlayer ??=
        players.contains('spotify')
            ? 'spotify'
            : (activePlayer ?? (players.isNotEmpty ? players.first : null));

    final shown =
        (details[_selectedPlayer] as Map?)?.cast<String, dynamic>() ??
        active ??
        <String, dynamic>{};
    final title = shown['title'] as String?;
    final artist = shown['artist'] as String?;
    final status = shown['status'] as String? ?? 'Stopped';
    final isPlaying = status.toLowerCase() == 'playing';
    final length = (shown['length'] as num?)?.toDouble();
    final position = (shown['position'] as num?)?.toDouble();

    final system = (state?['system'] as Map?)?.cast<String, dynamic>();
    final sysVolume = (system?['volume'] as num?)?.toDouble();
    _position ??= position ?? 0.0;

    // Live volume: follow telemetry unless the user is dragging the slider
    // (so laptop-side changes reflect on the phone).
    final currentVolume =
        (_volumeDragging
                ? (_systemVolume ?? 0)
                : (sysVolume ?? _systemVolume ?? 0))
            .clamp(0, 100)
            .toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Phase 3.7: swipe the now-playing card for previous / next.
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -350) {
              _control('media.next');
            } else if (velocity > 350) {
              _control('media.previous');
            }
          },
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MarqueeText(
                          text: title ?? 'Nothing playing',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  MarqueeText(
                    text: artist ?? '—',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                    duration: const Duration(milliseconds: 4000),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: isPlaying ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (_selectedPlayer != null)
                        Text(
                          _selectedPlayer!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  if (length != null && length > 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          _formatTime(_position ?? position ?? 0),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Expanded(
                          child: Slider(
                            value:
                                (_position ?? position ?? 0)
                                    .clamp(0, length)
                                    .toDouble(),
                            max: length,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (v) => setState(() => _position = v),
                            onChangeEnd: _seek,
                          ),
                        ),
                        Text(
                          _formatTime(length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transport',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (players.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPlayer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Player',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items:
                        players
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedPlayer = v;
                        _systemVolume = null;
                        _position = null;
                      });
                      _control('media.status');
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TransportButton(
                      icon: Icons.skip_previous,
                      label: 'Previous',
                      busy: _busyActions.contains('media.previous'),
                      onTap: () => _control('media.previous'),
                    ),
                    _TransportButton(
                      icon: isPlaying ? Icons.pause : Icons.play_arrow,
                      label: 'Play/Pause',
                      primary: true,
                      busy: _busyActions.contains('media.play_pause'),
                      onTap: () => _control('media.play_pause'),
                    ),
                    _TransportButton(
                      icon: Icons.skip_next,
                      label: 'Next',
                      busy: _busyActions.contains('media.next'),
                      onTap: () => _control('media.next'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.volume_down,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Expanded(
                      child: Slider(
                        value: currentVolume,
                        max: 100,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged:
                            (v) => setState(() {
                              _systemVolume = v;
                              _volumeDragging = true;
                            }),
                        onChangeEnd: _setVolume,
                      ),
                    ),
                    Icon(
                      Icons.volume_up,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${currentVolume.round()}%',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick open',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        actionId: 'media.open_spotify',
                        label: 'Spotify',
                        icon: Icons.queue_music,
                        onPressed: _openSpotify,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ActionButton(
                        actionId: 'system.open_url',
                        label: 'YouTube',
                        icon: Icons.play_circle_fill,
                        onPressed: () => _openUrl('https://www.youtube.com'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) seconds = 0;
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final bool busy;
  final VoidCallback onTap;

  const _TransportButton({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary ? color.primary : AppTheme.surfaceHigh,
            ),
            child:
                busy
                    ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Icon(
                      icon,
                      size: primary ? 32 : 26,
                      color: primary ? color.onPrimary : color.primary,
                    ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
