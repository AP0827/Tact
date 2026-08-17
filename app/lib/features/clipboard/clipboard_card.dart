import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../../theme.dart';

/// Clipboard bridge: shows what's on the laptop and lets the phone
/// overwrite it (or copy an entry back to the phone).
class ClipboardCard extends ConsumerStatefulWidget {
  const ClipboardCard({super.key});

  @override
  ConsumerState<ClipboardCard> createState() => _ClipboardCardState();
}

class _ClipboardCardState extends ConsumerState<ClipboardCard> {
  final _sendController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _sendController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    try {
      await ref.read(tactClientProvider).sendAction('clipboard.get');
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _sendToLaptop() async {
    final text = _sendController.text;
    if (text.trim().isEmpty) {
      _snack('Nothing to send');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(tactClientProvider)
          .sendAction('clipboard.set', {'text': text});
      _snack('Copied to laptop');
      _sendController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyToPhone(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) HapticFeedback.lightImpact();
      _snack('Copied to phone');
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tactStateProvider);
    final clipboard = (state?['clipboard'] as Map?)?.cast<String, dynamic>();

    if (clipboard == null || clipboard['available'] != true) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.content_paste,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Clipboard: ${clipboard?['error'] ?? 'unavailable'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final text = clipboard['text'] as String? ?? '';
    final history =
        (clipboard['history'] as List?)?.whereType<String>().toList() ??
            <String>[];
    final imageSupported = clipboard['image_supported'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.content_paste,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Clipboard', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              imageSupported
                  ? 'Image clipboard supported'
                  : 'Text clipboard only',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (text.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Copy to phone',
                      onPressed: () => _copyToPhone(text),
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('Laptop → Phone', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: _sendController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type something to copy to the laptop…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _sendToLaptop,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_busy ? 'Sending…' : 'Send to Laptop'),
              ),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Recent (from laptop)', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              ...history.take(5).map((h) => _HistoryRow(
                    text: h,
                    onCopy: () => _copyToPhone(h),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String text;
  final VoidCallback onCopy;

  const _HistoryRow({required this.text, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Copy to phone',
              onPressed: onCopy,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
