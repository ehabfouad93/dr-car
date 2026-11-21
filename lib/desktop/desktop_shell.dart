import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../ui/screens/history_screen.dart';
import '../ui/screens/live_screen.dart';
import '../ui/screens/modules_screen.dart';
import '../ui/screens/scan_screen.dart';
import '../obd/transport.dart';
import 'checklist.dart';
import 'serial_transport.dart';
import 'workbench.dart';
import 'desktop_pages.dart';

/// Desktop layout: side rail with every tool of the workbench.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});
  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int tab = 0;

  /// Developer shortcuts: LOGAN_CONNECT=127.0.0.1:35000 auto-connects to a
  /// Wi-Fi reader / emulator, LOGAN_TAB=n opens a tab, LOGAN_PROBES=1 runs the auto checks.
  @override
  void initState() {
    super.initState();
    final env = Platform.environment;
    tab = int.tryParse(env['LOGAN_TAB'] ?? '') ?? 0;
    final target = env['LOGAN_CONNECT'];
    if (target != null && target.contains(':')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final app = context.read<AppState>();
        final log = context.read<TrafficLog>();
        final wb = context.read<Workbench>();
        final parts = target.split(':');
        await app.connect(() async => LoggingTransport(await TcpTransport.connect(parts[0], int.parse(parts[1])), log));
        if (env['LOGAN_PROBES'] == '1') {
          for (final p in ['adapter', 'platform', 'modules', 'pids']) {
            await wb.runProbe(p);
          }
        }
        if (env['LOGAN_LIVE'] == '1') app.startMonitoring();
      });
    }
  }

  static const _pages = <(IconData, String, Widget)>[
    (Icons.cable, 'التوصيل', DesktopConnectPage()),
    (Icons.fact_check, 'قايمة التأكيد', ChecklistPage()),
    (Icons.search, 'فحص الموتور', ScanScreen()),
    (Icons.speed, 'العدادات', LiveScreen()),
    (Icons.show_chart, 'رسم بياني', ChartPage()),
    (Icons.hub, 'الكمبيوترات والتحكم', ModulesScreen()),
    (Icons.terminal, 'كونسول المطور', ConsolePage()),
    (Icons.history, 'السجل', HistoryScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cl = context.watch<Checklist>();
    return Scaffold(
      appBar: AppBar(
        title: Text('دكتور اللوجان — ${_pages[tab].$2}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.circle, size: 12, color: app.link == LinkState.connected ? Colors.green : Colors.grey),
              const SizedBox(width: 6),
              Text(app.link == LinkState.connected ? (app.linkLabel ?? '') : 'مش متوصل'),
              const SizedBox(width: 16),
              Text('قايمة التأكيد ${cl.doneCount}/${cl.items.length}'),
            ]),
          ),
        ],
      ),
      body: Row(children: [
        NavigationRail(
          selectedIndex: tab,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: [for (final p in _pages) NavigationRailDestination(icon: Icon(p.$1), label: Text(p.$2))],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _pages[tab].$3),
      ]),
    );
  }
}
