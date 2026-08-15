import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'host_status_service.dart';

class TrayController
    with TrayListener, WindowListener {
  TrayController(this._statusService);

  final HostStatusService _statusService;

  bool _initialized = false;
  bool _quitting = false;

  Future<void>? _menuUpdateInFlight;
  bool _menuUpdateQueued = false;

  int _lastPendingCount = 0;

  Future<void> init() async {
    if (_initialized) return;

    _initialized = true;

    trayManager.addListener(this);
    windowManager.addListener(this);

    await trayManager.setIcon(
      'assets/tray/tray_icon.png',
      isTemplate: Platform.isMacOS,
      iconSize: 18,
    );

    await trayManager.setToolTip('Tact');

    _statusService.addListener(
      _onStatusChanged,
    );

    await _rebuildMenu();

    _lastPendingCount =
        _statusService.status
                ?.pendingPairings.length ??
            0;
  }

  void _onStatusChanged() {
    if (_quitting) return;

    _menuUpdateQueued = true;

    if (_menuUpdateInFlight == null) {
      _menuUpdateInFlight =
          _drainMenuUpdates();
    }

    final pendingCount =
        _statusService.status
                ?.pendingPairings.length ??
            0;

    // A new request has arrived.
    if (pendingCount > _lastPendingCount) {
      unawaited(
        _openSettingsForApproval(),
      );
    }

    _lastPendingCount =
        pendingCount;
  }

  Future<void> _openSettingsForApproval() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      stderr.writeln(
        'Could not show approval window: $e',
      );
    }
  }

  Future<void> _drainMenuUpdates() async {
    try {
      while (_menuUpdateQueued &&
          !_quitting) {
        _menuUpdateQueued = false;

        await _rebuildMenu();
      }
    } finally {
      _menuUpdateInFlight = null;

      if (_menuUpdateQueued &&
          !_quitting) {
        _onStatusChanged();
      }
    }
  }

  Future<void> _rebuildMenu() async {
    final status =
        _statusService.status;

    final error =
        _statusService.lastError;

    final items = <MenuItem>[
      MenuItem(
        key: 'settings',
        label: 'Settings…',
      ),
      MenuItem.separator(),
    ];

    if (status != null) {
      items.addAll([
        MenuItem(
          key: 'hostname',
          label:
              'Host: ${status.hostname}',
          disabled: true,
        ),
        MenuItem(
          key: 'ip',
          label:
              'IP: ${status.ip}:${status.port}',
          disabled: true,
        ),
        MenuItem(
          key: 'paired_devices',
          label:
              'Paired devices: ${status.pairedDeviceCount}',
          disabled: true,
        ),
      ]);

      items.add(
        MenuItem(
          key: 'otp',
          label: status.otp == null
              ? 'OTP: expired'
              : 'OTP: ${status.otp} (${status.otpExpiresIn})',
          disabled: true,
        ),
      );

      if (status.otp == null) {
        items.add(
          MenuItem(
            key: 'regenerate_otp',
            label: 'Regenerate OTP',
          ),
        );
      }

      if (status.pendingPairings.isNotEmpty) {
        items.add(
          MenuItem.separator(),
        );

        items.add(
          MenuItem(
            key: 'pending',
            label:
                'Pending approvals: ${status.pendingPairings.length}',
            disabled: true,
          ),
        );

        items.add(
          MenuItem(
            key: 'review_approvals',
            label:
                'Review approvals…',
          ),
        );
      }
    } else {
      items.add(
        MenuItem(
          key: error == null
              ? 'loading'
              : 'unreachable',
          label: error == null
              ? 'Loading host status…'
              : 'Agent unreachable on port ${_statusService.port}',
          disabled: true,
        ),
      );
    }

    items.add(
      MenuItem.separator(),
    );

    items.add(
      MenuItem(
        key: 'refresh',
        label: 'Refresh',
      ),
    );

    items.add(
      MenuItem.separator(),
    );

    items.add(
      MenuItem(
        key: 'quit',
        label: 'Quit Tact',
      ),
    );

    await trayManager.setContextMenu(
      Menu(items: items),
    );
  }

  Future<void> _showSettings() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _regenerateOtp() async {
    try {
      await _statusService
          .regenerateOtp();
    } catch (e) {
      stderr.writeln(
        'Could not regenerate OTP: $e',
      );
    }
  }

  Future<void> _quit() async {
    if (_quitting) return;

    _quitting = true;

    _statusService.removeListener(
      _onStatusChanged,
    );

    _statusService.dispose();

    trayManager.removeListener(
      this,
    );

    windowManager.removeListener(
      this,
    );

    try {
      await trayManager.destroy();
    } finally {
      try {
        await windowManager
            .setPreventClose(false);
      } catch (_) {}

      exit(0);
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(
      trayManager.popUpContextMenu(),
    );
  }

  @override
  void onTrayMenuItemClick(
    MenuItem menuItem,
  ) {
    switch (menuItem.key) {
      case 'settings':
        unawaited(
          _showSettings(),
        );
        break;

      case 'review_approvals':
        unawaited(
          _showSettings(),
        );
        break;

      case 'regenerate_otp':
        unawaited(
          _regenerateOtp(),
        );
        break;

      case 'refresh':
        unawaited(
          _statusService.refreshNow(),
        );
        break;

      case 'quit':
        unawaited(_quit());
        break;
    }
  }

  @override
  void onWindowClose() {
    if (_quitting) return;

    unawaited(
      windowManager.hide(),
    );
  }
}