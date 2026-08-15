import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'host/host_status_service.dart';
import 'host/settings_screen.dart';
import 'host/settings_store.dart';
import 'host/tray_controller.dart';
import 'theme.dart';

late final HostStatusService _statusService;
late final TrayController _trayController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final port = await SettingsStore().loadPort();
  _statusService = HostStatusService(port: port);

  const windowOptions = WindowOptions(
    size: Size(440, 640),
    center: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(
    windowOptions,
    () async {
      await windowManager.setPreventClose(true);
      await windowManager.hide();
    },
  );

  runApp(
    TactTrayApp(
      statusService: _statusService,
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_startServices());
  });
}

Future<void> _startServices() async {
  try {
    await _statusService.start();
  } catch (e, stackTrace) {
    debugPrint('HostStatusService startup error: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    _trayController = TrayController(_statusService);
    await _trayController.init();
  } catch (e, stackTrace) {
    debugPrint('TrayController startup error: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class TactTrayApp extends StatelessWidget {
  const TactTrayApp({
    super.key,
    required this.statusService,
  });

  final HostStatusService statusService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tact',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: SettingsScreen(
        statusService: statusService,
      ),
    );
  }
}
