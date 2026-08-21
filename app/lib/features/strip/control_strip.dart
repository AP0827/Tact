import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../../theme.dart';

/// Phase 4 Control Strip — a compact, persistent bar above the navigation
/// bar. Stays small by design: one tap expands a full bottom sheet with
/// volume, brightness, and audio-output controls.
class ControlStrip extends ConsumerStatefulWidget {
  const ControlStrip({super.key});

  @override
  ConsumerState<ControlStrip> createState() => _ControlStripState();
}

class _ControlStripState extends ConsumerState<ControlStrip> {
  bool _volumeDragging = false;
  double? _localVolume;

  double _volume(Map<String, dynamic>? state) {
    final system = (state?['system'] as Map?)?.cast<String, dynamic>();
    final sysVolume = (system?['volume'] as num?)?.toDouble();
    if (_volumeDragging) return (_localVolume ?? 0).clamp(0, 100);
    return (sysVolume ?? 0).clamp(0, 100);
  }

  Future<void> _send(String action, [Map<String, dynamic>? payload]) async {
    try {
      await ref.read(tactClientProvider).sendAction(action, payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ControlSheet(onSend: _send),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tactStateProvider);
    final volume = _volume(state);

    return Material(
      color: AppTheme.surfaceHigh.withValues(alpha: 0.6),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
          child: Row(
            children: [
              _StripIconButton(
                icon: Icons.volume_up,
                tooltip: 'Volume & output',
                onTap: _openSheet,
              ),
              Expanded(
                child: Slider(
                  value: volume,
                  max: 100,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.primary.withValues(alpha: 0.2),
                  onChanged:
                      (v) => setState(() {
                        _localVolume = v;
                        _volumeDragging = true;
                      }),
                  onChangeEnd: (v) {
                    setState(() => _volumeDragging = false);
                    _send('system.volume', {'value': v.round()});
                  },
                ),
              ),
              _StripIconButton(
                icon: Icons.play_arrow,
                tooltip: 'Play / Pause',
                onTap: () => _send('media.play_pause'),
              ),
              _StripIconButton(
                icon: Icons.screenshot,
                tooltip: 'Screenshot',
                onTap: () => _send('system.screenshot'),
              ),
              _StripIconButton(
                icon: Icons.lock,
                tooltip: 'Lock screen',
                onTap: () => _send('system.lock_screen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _StripIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: onTap,
      ),
    );
  }
}

/// Expanded control sheet: volume + brightness sliders and audio outputs.
class _ControlSheet extends ConsumerStatefulWidget {
  final Future<void> Function(String action, [Map<String, dynamic>? payload])
  onSend;

  const _ControlSheet({required this.onSend});

  @override
  ConsumerState<_ControlSheet> createState() => _ControlSheetState();
}

class _ControlSheetState extends ConsumerState<_ControlSheet> {
  bool _volumeDragging = false;
  bool _brightnessDragging = false;
  double? _localVolume;
  double? _localBrightness;

  double _value(String key, double? local, bool dragging) {
    final state = ref.watch(tactStateProvider);
    final system = (state?['system'] as Map?)?.cast<String, dynamic>();
    final snap = (system?[key] as num?)?.toDouble();
    if (dragging) return (local ?? 0).clamp(0, 100);
    return (snap ?? 0).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tactStateProvider);
    final system = (state?['system'] as Map?)?.cast<String, dynamic>();
    final sinks = (system?['sinks'] as List?) ?? const [];
    final sources = (system?['sources'] as List?) ?? const [];
    final volume = _value('volume', _localVolume, _volumeDragging);
    final brightness = _value(
      'brightness',
      _localBrightness,
      _brightnessDragging,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SliderRow(
            icon: Icons.volume_up,
            label: 'Volume',
            value: volume,
            onChanged:
                (v) => setState(() {
                  _localVolume = v;
                  _volumeDragging = true;
                }),
            onChangeEnd: (v) {
              setState(() => _volumeDragging = false);
              widget.onSend('system.volume', {'value': v.round()});
            },
            trailing: IconButton(
              icon: const Icon(Icons.volume_off, size: 20),
              tooltip: 'Mute',
              onPressed: () => widget.onSend('system.mute'),
            ),
          ),
          const SizedBox(height: 8),
          _SliderRow(
            icon: Icons.brightness_6,
            label: 'Brightness',
            value: brightness,
            onChanged:
                (v) => setState(() {
                  _localBrightness = v;
                  _brightnessDragging = true;
                }),
            onChangeEnd: (v) {
              setState(() => _brightnessDragging = false);
              widget.onSend('system.brightness', {'value': v.round()});
            },
          ),
          if (sinks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Audio output', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sink in sinks.cast<Map>())
                  ChoiceChip(
                    label: Text(
                      (sink['name'] as String? ?? '?').split('.').last,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: sink['default'] == true,
                    onSelected:
                        (_) => widget.onSend('system.set_sink', {
                          'sink': sink['name'],
                        }),
                  ),
              ],
            ),
          ],
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.mic, size: 16, color: AppTheme.muted),
                const SizedBox(width: 6),
                Text(
                  'Microphone',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final source in sources.cast<Map>())
                  ChoiceChip(
                    label: Text(
                      (source['name'] as String? ?? '?').split('.').last,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: source['default'] == true,
                    onSelected:
                        (_) => widget.onSend('system.set_source', {
                          'source': source['name'],
                        }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final Widget? trailing;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            max: 100,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.primary.withValues(alpha: 0.2),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${value.round()}%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
