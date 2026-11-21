import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../obd/pids.dart';
import '../../services/app_state.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late final AppState app = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    app.showAllPids = true;
  }

  @override
  void dispose() {
    app.showAllPids = false; // background monitor goes back to the 3 alert PIDs
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.link != LinkState.connected) {
      return const Center(child: Text('وصّل القارئ الأول.'));
    }
    final coolant = app.live[pidCoolant];
    final volts = app.readerVolts;
    return ListView(padding: const EdgeInsets.all(16), children: [
      SwitchListTile(
        title: const Text('المراقبة والتنبيهات أثناء السواقة'),
        subtitle: const Text('شغالة حتى والشاشة مقفولة'),
        value: app.monitoring,
        onChanged: (v) => v ? app.startMonitoring() : setState(app.stopMonitoring),
      ),
      // Big numeric coolant: the Logan cluster only shows bars.
      Row(children: [
        Expanded(child: _big('حرارة المياه', coolant == null ? '--' : '${coolant.round()}°', _tempColor(coolant))),
        const SizedBox(width: 12),
        Expanded(child: _big('البطارية', volts == null ? '--' : volts.toStringAsFixed(1), _voltColor(volts, app.live[pidRpm]))),
      ]),
      if (!app.monitoring)
        const Padding(padding: EdgeInsets.all(12), child: Text('شغّل المراقبة عشان القراءات تتحدث.', textAlign: TextAlign.center)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.9,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (final p in app.livePidList.where((p) => p != pidCoolant))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(livePids[p]!.nameAr, style: const TextStyle(fontSize: 12)),
                  Text(
                    app.live[p] == null ? '--' : '${app.live[p]!.toStringAsFixed(p == 0x14 || p == 0x15 || p == pidControlVoltage ? 2 : 0)} ${livePids[p]!.unit}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ),
        ],
      ),
      if (app.recentAlerts.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('آخر التنبيهات', style: Theme.of(context).textTheme.titleMedium),
        for (final a in app.recentAlerts.take(5)) Card(child: ListTile(title: Text(a.titleAr), subtitle: Text(a.bodyAr))),
      ],
    ]);
  }

  Color _tempColor(double? c) => c == null ? Colors.grey : c > 105 ? Colors.red : c > 98 ? Colors.orange : Colors.green;

  Color _voltColor(double? v, double? rpm) {
    if (v == null) return Colors.grey;
    final running = (rpm ?? 0) > 500;
    if (running) return v < 13.2 || v > 15 ? Colors.red : Colors.green;
    return v < 12.2 ? Colors.red : v < 12.4 ? Colors.orange : Colors.green;
  }

  Widget _big(String label, String value, Color color) => Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Text(label),
            Text(value, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      );
}
