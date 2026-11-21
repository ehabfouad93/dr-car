import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/dtc_repo.dart';
import 'desktop/checklist.dart';
import 'desktop/desktop_shell.dart';
import 'desktop/serial_transport.dart';
import 'desktop/workbench.dart';
import 'obd/bt_transport.dart';
import 'services/app_state.dart';
import 'services/renault_controller.dart';
import 'ui/screens/connect_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/live_screen.dart';
import 'ui/screens/modules_screen.dart';
import 'ui/screens/scan_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dtc = DtcRepo(await rootBundle.loadString('assets/logan_dtc.json'));
  final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  // Phone notifications only on Android; desktop shows alerts inside the app.
  final app = AppState(dtc: dtc, notifier: desktop ? null : (a) => NativeBt.notify(a.id, a.titleAr, a.bodyAr));
  final renault = RenaultController(app)..loadSavedDefinitions();
  final checklist = Checklist()..load();
  final log = TrafficLog();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app),
      ChangeNotifierProvider.value(value: renault),
      ChangeNotifierProvider.value(value: checklist),
      ChangeNotifierProvider.value(value: log),
      ChangeNotifierProvider(create: (_) => Workbench(app, renault, checklist, log)),
    ],
    child: LoganDoctorApp(desktop: desktop),
  ));
}

class LoganDoctorApp extends StatelessWidget {
  const LoganDoctorApp({super.key, this.desktop = false});
  final bool desktop;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'دكتور اللوجان',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Arabic-first: whole app right-to-left.
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: desktop ? const DesktopShell() : const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  static const _titles = ['التوصيل', 'فحص الأعطال', 'القراءات الحية', 'كل الكمبيوترات', 'السجل'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _disclaimerOnce());
  }

  Future<void> _disclaimerOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('disclaimer_ok') == true || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('أهلًا بيك في دكتور اللوجان'),
        content: const Text('التطبيق معمول لرينو لوجان 2015 مانيوال (موتور 1.6 K7M).\n\n'
            '• التطبيق بيرشدك، والميكانيكي هو اللي يقرر.\n'
            '• القراءة آمنة دايمًا. أي أمر بيغيّر حاجة في العربية هيسألك الأول، وممنوع والعربية ماشية.\n'
            '• التطبيق عمره ما هيبرمج الكمبيوتر أو يغيّر الكيلومترات.\n'
            '• شيل القارئ من الفيشة لما تركن عشان البطارية.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('فهمت'))],
      ),
    );
    await prefs.setBool('disclaimer_ok', true);
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [ConnectScreen(), ScanScreen(), LiveScreen(), ModulesScreen(), HistoryScreen()];
    return Scaffold(
      appBar: AppBar(title: Text(_titles[tab])),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bluetooth), label: 'التوصيل'),
          NavigationDestination(icon: Icon(Icons.search), label: 'الفحص'),
          NavigationDestination(icon: Icon(Icons.speed), label: 'القراءات'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'الكمبيوترات'),
          NavigationDestination(icon: Icon(Icons.history), label: 'السجل'),
        ],
      ),
    );
  }
}
