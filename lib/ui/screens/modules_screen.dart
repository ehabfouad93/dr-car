import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../obd/ddt.dart';
import '../../obd/renault.dart';
import '../../services/app_state.dart';
import '../../services/renault_controller.dart';

/// All computers in the car: scan, faults, every sensor, control tests.
class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final rc = context.watch<RenaultController>();
    if (app.link != LinkState.connected) return const Center(child: Text('وصّل القارئ الأول.'));
    return ListView(padding: const EdgeInsets.all(16), children: [
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: rc.busy ? null : rc.scanAll,
        icon: const Icon(Icons.hub),
        label: const Text('افحص كل كمبيوترات العربية'),
      ),
      if (rc.busy) ...[const LinearProgressIndicator(), Text(rc.status)],
      if (rc.errorAr != null) Text(rc.errorAr!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 8),
      const Text('محتاج قارئ ELM327 v1.5 أصلي أو vLinker / OBDLink. القارئات المقلدة v2.1 غالبًا مش هتقدر تكلم غير الموتور.',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
      for (final m in loganModules)
        if (m.likelyFitted || rc.scans[m.diagAddr]?.answered == true) _tile(context, rc, m),
    ]);
  }

  Widget _tile(BuildContext context, RenaultController rc, RenaultModule m) {
    final s = rc.scans[m.diagAddr];
    final (icon, color, sub) = s == null
        ? (Icons.help_outline, Colors.grey, 'لسه متفحصش')
        : !s.answered
            ? (Icons.cloud_off, Colors.grey, 'مردش (ممكن مش موجود في العربية دي)')
            : s.dtcs.isEmpty
                ? (Icons.check_circle, Colors.green, 'مفيش أعطال')
                : (Icons.warning_amber, Colors.orange, '${s.dtcs.length} عطل');
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(m.nameAr),
        subtitle: Text('$sub${rc.ecus.containsKey(m.diagAddr) ? '  •  ملف التعريف محمّل' : ''}'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModuleDetailScreen(module: m))),
      ),
    );
  }
}

class ModuleDetailScreen extends StatelessWidget {
  const ModuleDetailScreen({super.key, required this.module});
  final RenaultModule module;

  Future<void> _import(BuildContext context, RenaultController rc) async {
    final files = await FilePicker.pickFiles(dialogTitle: 'اختار ملف تعريف الكمبيوتر (JSON)');
    if (files.isEmpty) return;
    final err = await rc.importDefinition(module, await files.first.xFile.readAsString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'اتحمّل ملف التعريف.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RenaultController>();
    final s = rc.scans[module.diagAddr];
    final ecu = rc.ecus[module.diagAddr];
    final noControl = RenaultController.noControlModules.contains(module.diagAddr);
    return Scaffold(
      appBar: AppBar(title: Text(module.nameAr)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('CAN: ${module.tx} → ${module.rx}', textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.grey)),
        if (s?.identHex.isNotEmpty == true)
          Text('تعريف الكمبيوتر: ${s!.identHex}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        if (rc.busy) ...[const LinearProgressIndicator(), Text(rc.status)],
        if (rc.errorAr != null) Text(rc.errorAr!, style: const TextStyle(color: Colors.red)),

        // ---- Faults ----
        const SizedBox(height: 12),
        Text('الأعطال', style: Theme.of(context).textTheme.titleMedium),
        if (s == null || !s.answered) const Text('افحص الأول من الصفحة اللي قبلها.'),
        if (s != null && s.answered && s.dtcs.isEmpty) const Text('مفيش أعطال 👍'),
        for (final c in s?.dtcs ?? <RawDtc>[])
          Card(
            child: ListTile(
              title: Text(c.label, textDirection: TextDirection.ltr),
              subtitle: Text('${rc.dtcName(module, c) ?? 'حمّل ملف التعريف عشان تظهر التفاصيل'}\n'
                  '${c.present ? 'موجود دلوقتي' : 'متسجل (مش موجود دلوقتي)'}'),
            ),
          ),
        if (s != null && s.dtcs.isNotEmpty)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: rc.busy ? null : () => _clear(context, rc),
            icon: const Icon(Icons.delete_outline),
            label: const Text('امسح أعطال الكمبيوتر ده'),
          ),

        // ---- Definition file ----
        const Divider(height: 32),
        Text('ملف التعريف (DDT4ALL)', style: Theme.of(context).textTheme.titleMedium),
        Text(ecu == null
            ? 'عشان تقرا كل الحساسات وتعمل اختبارات تحكم، حمّل ملف JSON الخاص بالكمبيوتر ده من قاعدة بيانات DDT4ALL بتاعتك.'
            : '${ecu.name}: ${ecu.readRequests.length} مجموعة قراءات، ${ecu.controlRequests.length} اختبار تحكم'),
        TextButton.icon(onPressed: () => _import(context, rc), icon: const Icon(Icons.upload_file), label: const Text('حمّل ملف تعريف')),

        if (ecu != null) ...[
          // ---- All sensors ----
          const Divider(height: 32),
          Row(children: [
            Text('كل الحساسات والقراءات', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.tonal(onPressed: rc.busy ? null : () => rc.readAll(module), child: const Text('اقرا الكل')),
          ]),
          for (final r in ecu.readRequests)
            for (final it in r.recvItems)
              if (rc.values.containsKey('${module.diagAddr}/${it.name}'))
                ListTile(
                  dense: true,
                  title: Text(it.name),
                  trailing: Text(rc.values['${module.diagAddr}/${it.name}']!, textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),

          // ---- Control tests ----
          const Divider(height: 32),
          Text('اختبارات التحكم', style: Theme.of(context).textTheme.titleMedium),
          if (noControl)
            const Text('التحكم في الفرامل والإيرباج والدركسيون ممنوع في التطبيق للأمان. ده شغل مركز متخصص.', style: TextStyle(color: Colors.red))
          else ...[
            const Text('العربية لازم تكون واقفة، والموتور مطفي والكونتاكت شغال. كل اختبار بيقف لوحده بعد الوقت المحدد.',
                style: TextStyle(fontSize: 12)),
            if (rc.activeTest != null)
              Card(
                color: Colors.amber.shade100,
                child: ListTile(
                  title: Text('شغال: ${rc.activeTest!.name}'),
                  subtitle: Text('هيقف بعد ${rc.secondsLeft} ثانية'),
                  trailing: FilledButton(onPressed: rc.stopTest, child: const Text('وقّف')),
                ),
              ),
            for (final r in ecu.controlRequests)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(r.name),
                  onTap: rc.busy ? null : () => _runTest(context, rc, ecu, r),
                ),
              ),
          ],
        ],
      ]),
    );
  }

  Future<void> _clear(BuildContext context, RenaultController rc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('مسح أعطال ${module.nameAr}'),
        content: const Text('صلّحت السبب؟ المسح بيشيل الدليل. الكونتاكت شغال والعربية واقفة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('رجوع')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('امسح')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await rc.clearModule(module);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'اتمسحت.')));
  }

  Future<void> _runTest(BuildContext context, RenaultController rc, DdtEcu ecu, DdtRequest r) async {
    final chosen = <String, int>{};
    var seconds = 10.0;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(r.name),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final it in r.sendItems)
                if (ecu.data[it.name]?.lists.isNotEmpty == true) ...[
                  Text(it.name, style: const TextStyle(fontSize: 12)),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: chosen[it.name],
                    hint: const Text('اختار'),
                    items: [
                      for (final e in ecu.data[it.name]!.lists.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => set(() => chosen[it.name] = v!),
                  ),
                ],
              Text('مدة الاختبار: ${seconds.round()} ثانية'),
              Slider(min: 2, max: 30, divisions: 28, value: seconds, onChanged: (v) => set(() => seconds = v)),
              const Text('⚠️ خلي إيدك بعيد عن المروحة والسيور.', style: TextStyle(color: Colors.red)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('شغّل')),
          ],
        ),
      ),
    );
    if (go != true) return;
    final err = await rc.runTest(module, r, chosen, seconds: seconds.round());
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'الاختبار خلص ورجّعنا التحكم للكمبيوتر.')));
  }
}
