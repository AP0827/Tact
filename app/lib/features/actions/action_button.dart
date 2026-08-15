import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';

class ActionButton
    extends ConsumerStatefulWidget {
  final String actionId;
  final String label;
  final IconData? icon;
  final Map<String, dynamic>? payload;

  /// Custom handler; when provided it replaces the default sendAction call.
  final Future<void> Function()? onPressed;

  const ActionButton({
    super.key,
    required this.actionId,
    required this.label,
    this.icon,
    this.payload,
    this.onPressed,
  });

  @override
  ConsumerState<ActionButton> createState() =>
      _ActionButtonState();
}

class _ActionButtonState
    extends ConsumerState<ActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      if (widget.onPressed != null) {
        await widget.onPressed!();
      } else {
        await ref
            .read(tactClientProvider)
            .sendAction(
              widget.actionId,
              widget.payload,
            );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${widget.label} failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      borderRadius:
          BorderRadius.circular(22),
      child: InkWell(
        onTap: _busy ? null : _run,
        borderRadius:
            BorderRadius.circular(22),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              if (_busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  widget.icon ??
                      Icons.bolt,
                  size: 24,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),

              const SizedBox(height: 8),

              Text(
                widget.label,
                textAlign:
                    TextAlign.center,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}