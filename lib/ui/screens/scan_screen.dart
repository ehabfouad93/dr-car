import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/dtc_repo.dart';
import '../../data/models.dart';
import '../../services/app_state.dart';
import '../../services/safety.dart';
import '../theme.dart';
import 'code_detail_screen.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.link != LinkState.connected) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('وصّل القارئ الأول من صفحة "التوصيل".', textAlign: TextAlign.center)));
    }
    final scan = app.lastScan;
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Rescan on top. Clear lives far away at the bottom (plan rule).
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: app.busy ? null : () => app.scan(),
        icon: const Icon(Icons.search),
        label: Text(scan == null ? 'افحص العربية' : 'افحص تاني'),
      ),
      if (app.busy) ...[const SizedBox(height: 12), LinearProgressIndicator(), Text(app.busyAr)],
      if (app.errorAr != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(app.errorAr!, style: const TextStyle(color: Colors.red))),
      if (scan != null) ..._results(context, app, scan),
    ]);
  }

  List<Widget> _results(BuildContext context, AppState app, ScanResult scan) {
    final infos = {for (final c in scan.codes) c.code: app.dtc.lookup(c.code)};
    return [
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.engineering, color: scan.milOn ? Colors.orange : Colors.green),
              const SizedBox(width: 8),
              Text(scan.milOn ? 'لمبة المحرك منورة' : 'لمبة المحرك مطفية', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            if (!scan.milOn && scan.codes.isNotEmpty)
              const Text('اللمبة مطفية بس في أكواد متسجلة. ده مش معناه إن كل حاجة تمام.', style: TextStyle(color: Colors.orange)),
            if (scan.batteryVolts != null) Text('فولت البطارية: ${scan.batteryVolts!.toStringAsFixed(1)} V'),
            const SizedBox(height: 6),
            Text('ردّوا: ${scan.modulesAnswered.isEmpty ? '—' : scan.modulesAnswered.join('، ')}'),
            if (scan.modulesSilent.isNotEmpty)
              Text('مردوش: ${scan.modulesSilent.join('، ')} (السكان مش كامل)', style: const TextStyle(color: Colors.red)),
          ]),
        ),
      ),
      if (scan.codes.isEmpty)
        const Card(child: ListTile(leading: Icon(Icons.verified, color: Colors.green), title: Text('مفيش أعطال متسجلة في كمبيوتر الموتور 👍'))),
      for (final c in scan.codes)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: severityColor(infos[c.code]!.severity), width: 1.5),
          ),
          child: ListTile(
            title: Row(children: [
              Text(c.code, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              SeverityChip(infos[c.code]!.severity),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              Text(infos[c.code]!.nameAr, style: const TextStyle(fontSize: 15)),
              Text(c.status.labelAr, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ]),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CodeDetailScreen(found: c))),
          ),
        ),
      const SizedBox(height: 48),
      if (scan.codes.isNotEmpty)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          onPressed: app.busy ? null : () => _confirmClear(context, app),
          icon: const Icon(Icons.delete_outline),
          label: const Text('امسح الأكواد'),
        ),
      const SizedBox(height: 24),
    ];
  }

  Future<void> _confirmClear(BuildContext context, AppState app) async {
    final hasStop = app.lastScan!.codes.any((c) => app.dtc.lookup(c.code).severity == Severity.stop);
    final first = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('قبل ما تمسح'),
        content: Text(SafetyGuard.clearWarningAr +
            (hasStop ? '\n\n⚠️ في عطل خطير. المسح مش هيصلحه، والعطل هيرجع.' : '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لأ، رجوع')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('أيوه صلّحته')),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد أخير'),
        content: const Text('هنمسح كل أكواد كمبيوتر الموتور دلوقتي. متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('امسح')),
        ],
      ),
    );
    if (second != true) return;
    final err = await app.clearCodes();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'اتمسحت. اعمل سكان تاني بعد 2-3 مشاوير عشان تتأكد إن العطل اتصلح.'),
      ));
    }
  }
}
