import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'host_status.dart';
import 'host_status_service.dart';
import 'settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.statusService,
  });

  final HostStatusService statusService;

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  final _store = SettingsStore();
  final _portController =
      TextEditingController();

  bool _saving = false;
  bool _showingApprovals = false;

  final Set<String> _shownApprovalIds = {};

  @override
  void initState() {
    super.initState();

    _portController.text =
        widget.statusService.port.toString();

    widget.statusService.addListener(
      _onStatusChanged,
    );

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _checkForApprovals();
    });
  }

  @override
  void dispose() {
    widget.statusService.removeListener(
      _onStatusChanged,
    );

    _portController.dispose();

    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted) return;

    setState(() {});

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _checkForApprovals();
    });
  }

  void _checkForApprovals() {
    if (!mounted || _showingApprovals) {
      return;
    }

    final pending =
        widget.statusService.status?.pendingPairings ??
            const <PendingPairing>[];

    if (pending.isEmpty) {
      _shownApprovalIds.clear();
      return;
    }

    final newRequests = pending
        .where(
          (p) => !_shownApprovalIds.contains(
            p.pendingId,
          ),
        )
        .toList();

    if (newRequests.isEmpty) {
      return;
    }

    for (final request in newRequests) {
      _shownApprovalIds.add(
        request.pendingId,
      );
    }

    unawaited(
      _showApprovalSheet(),
    );
  }

  Future<void> _showApprovalSheet() async {
    if (!mounted || _showingApprovals) {
      return;
    }

    _showingApprovals = true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor:
            Colors.black.withValues(alpha: 0.45),
        builder: (_) {
          return _ApprovalSheet(
            statusService:
                widget.statusService,
          );
        },
      );
    } finally {
      _showingApprovals = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _savePort() async {
    final parsed =
        int.tryParse(
          _portController.text.trim(),
        );

    if (parsed == null ||
        parsed < 1 ||
        parsed > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid port (1–65535)',
          ),
        ),
      );

      return;
    }

    setState(() => _saving = true);

    try {
      await _store.savePort(parsed);

      await widget.statusService
          .updatePort(parsed);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _regenerateOtp() async {
    try {
      await widget.statusService
          .regenerateOtp();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A new OTP has been generated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not regenerate OTP: $e',
          ),
        ),
      );
    }
  }

  void _copy(String? value) {
    if (value == null) return;

    Clipboard.setData(
      ClipboardData(text: value),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status =
        widget.statusService.status;

    final unreachable =
        status == null &&
            widget.statusService.lastError != null;

    final pending =
        status?.pendingPairings ??
            const <PendingPairing>[];

    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF8F5),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFFFF8F5),
        surfaceTintColor:
            Colors.transparent,
        title: const Text('Tact Settings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              unawaited(
                widget.statusService
                    .refreshNow(),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionCard(
            title: 'This host',
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (unreachable)
                  const Text(
                    'Agent unreachable on 127.0.0.1.',
                    style: TextStyle(
                      color: Colors.orange,
                    ),
                  )
                else if (status == null)
                  const Text('Loading…')
                else ...[
                  _InfoRow(
                    label: 'Hostname',
                    value: status.hostname,
                  ),
                  _InfoRow(
                    label: 'IP address',
                    value: status.ip,
                    onCopy: () =>
                        _copy(status.ip),
                  ),
                  _OtpRow(
                    status: status,
                    onRegenerate:
                        _regenerateOtp,
                    onCopy: _copy,
                  ),
                  _InfoRow(
                    label: 'Paired devices',
                    value:
                        '${status.pairedDeviceCount}',
                  ),
                ],
              ],
            ),
          ),

          if (pending.isNotEmpty) ...[
            const SizedBox(height: 16),

            _PendingApprovalsCard(
              statusService:
                  widget.statusService,
              pending: pending,
              onOpen:
                  _showApprovalSheet,
            ),
          ],

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Agent connection',
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                TextField(
                  controller:
                      _portController,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      const InputDecoration(
                    labelText: 'Agent port',
                    helperText:
                        'Default: 8000',
                  ),
                ),

                const SizedBox(height: 12),

                Align(
                  alignment:
                      Alignment.centerRight,
                  child: FilledButton(
                    onPressed:
                        _saving
                            ? null
                            : _savePort,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: TextButton(
              onPressed: () {
                unawaited(
                  windowManager.hide(),
                );
              },
              child: const Text(
                'Close — keep Tact running',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalSheet extends StatefulWidget {
  const _ApprovalSheet({
    required this.statusService,
  });

  final HostStatusService statusService;

  @override
  State<_ApprovalSheet> createState() =>
      _ApprovalSheetState();
}

class _ApprovalSheetState
    extends State<_ApprovalSheet> {
  final Set<String> _busy = {};

  Future<void> _approve(
    PendingPairing pairing,
  ) async {
    if (_busy.contains(pairing.pendingId)) {
      return;
    }

    setState(() {
      _busy.add(pairing.pendingId);
    });

    try {
      await widget.statusService
          .approvePairing(
        pairing.pendingId,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not approve ${pairing.label}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(
            pairing.pendingId,
          );
        });
      }
    }
  }

  Future<void> _reject(
    PendingPairing pairing,
  ) async {
    if (_busy.contains(pairing.pendingId)) {
      return;
    }

    setState(() {
      _busy.add(pairing.pendingId);
    });

    try {
      await widget.statusService
          .rejectPairing(
        pairing.pendingId,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not reject ${pairing.label}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(
            pairing.pendingId,
          );
        });
      }
    }
  }

  Future<void> _approveAll() async {
    final pending =
        widget.statusService.status
                ?.pendingPairings ??
            const <PendingPairing>[];

    for (final pairing
        in List<PendingPairing>.from(
      pending,
    )) {
      await _approve(pairing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        widget.statusService.status
                ?.pendingPairings ??
            const <PendingPairing>[];

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F5),
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 30,
            spreadRadius: 2,
            offset: Offset(0, -5),
            color: Colors.black26,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pending Approvals  ${pending.length}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(
                    Icons.close,
                  ),
                  onPressed: () =>
                      Navigator.of(
                    context,
                  ).pop(),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              'New devices want to pair with this host.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),

            const SizedBox(height: 14),

            if (pending.isEmpty)
              const Padding(
                padding:
                    EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No pending approvals.',
                  ),
                ),
              )
            else
              ...pending.map(
                (pairing) =>
                    _ApprovalItem(
                  pairing: pairing,
                  busy: _busy.contains(
                    pairing.pendingId,
                  ),
                  onApprove: () =>
                      _approve(pairing),
                  onReject: () =>
                      _reject(pairing),
                ),
              ),

            if (pending.length > 1) ...[
              const SizedBox(height: 10),

              Center(
                child: FilledButton.icon(
                  onPressed:
                      _busy.isNotEmpty
                          ? null
                          : _approveAll,
                  icon: const Icon(
                    Icons.verified_user,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'Approve All',
                  ),
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFFDFF3DC,
                    ),
                    foregroundColor:
                        const Color(
                      0xFF27833A,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ApprovalItem
    extends StatelessWidget {
  const _ApprovalItem({
    required this.pairing,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final PendingPairing pairing;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFFFE9DD),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_iphone,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  pairing.label,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pairing.deviceId,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                if (pairing.createdAt !=
                    null)
                  Text(
                    _formatDate(
                      pairing.createdAt!,
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          else ...[
            TextButton.icon(
              onPressed: onApprove,
              icon: const Icon(
                Icons.check,
                size: 16,
              ),
              label:
                  const Text('Approve'),
              style:
                  TextButton.styleFrom(
                foregroundColor:
                    const Color(
                  0xFF27833A,
                ),
                backgroundColor:
                    const Color(
                  0xFFE5F5E1,
                ),
              ),
            ),

            const SizedBox(width: 6),

            TextButton.icon(
              onPressed: onReject,
              icon: const Icon(
                Icons.close,
                size: 16,
              ),
              label:
                  const Text('Reject'),
              style:
                  TextButton.styleFrom(
                foregroundColor:
                    const Color(
                  0xFFB84B36,
                ),
                backgroundColor:
                    const Color(
                  0xFFFFE5DC,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(
    DateTime date,
  ) {
    final hour =
        date.hour % 12 == 0
            ? 12
            : date.hour % 12;

    final minute =
        date.minute.toString().padLeft(
              2,
              '0',
            );

    final suffix =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return 'Today, $hour:$minute $suffix';
  }
}

class _PendingApprovalsCard
    extends StatelessWidget {
  const _PendingApprovalsCard({
    required this.statusService,
    required this.pending,
    required this.onOpen,
  });

  final HostStatusService statusService;
  final List<PendingPairing> pending;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title:
          'Pending Approvals  ${pending.length}',
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'New devices are waiting for approval.',
          ),

          const SizedBox(height: 12),

          ...pending.map(
            (p) => ListTile(
              contentPadding:
                  EdgeInsets.zero,
              leading: const Icon(
                Icons.phone_iphone,
              ),
              title: Text(p.label),
              subtitle:
                  Text(p.deviceId),
              trailing:
                  const Icon(
                Icons.chevron_right,
              ),
              onTap: onOpen,
            ),
          ),

          const SizedBox(height: 4),

          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(
              Icons.verified_user,
            ),
            label:
                const Text(
              'Review approvals',
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpRow
    extends StatelessWidget {
  const _OtpRow({
    required this.status,
    required this.onRegenerate,
    required this.onCopy,
  });

  final HostStatus status;
  final VoidCallback onRegenerate;
  final void Function(String?) onCopy;

  @override
  Widget build(BuildContext context) {
    final active = status.otp != null;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 110,
            child: Text(
              'OTP',
              style: TextStyle(
                fontSize: 12,
              ),
            ),
          ),

          Expanded(
            child: SelectableText(
              active
                  ? '${status.otp} · ${status.otpExpiresIn}'
                  : 'expired',
            ),
          ),

          if (active)
            IconButton(
              icon: const Icon(
                Icons.copy,
                size: 16,
              ),
              onPressed: () =>
                  onCopy(status.otp),
            )
          else
            TextButton(
              onPressed: onRegenerate,
              child:
                  const Text(
                'Regenerate',
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard
    extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: const Color(0xFFFFF1EA),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(
                Icons.copy,
                size: 16,
              ),
              tooltip: 'Copy',
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}