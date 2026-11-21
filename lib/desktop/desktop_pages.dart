import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../obd/elm327.dart';
import '../obd/pids.dart';
import '../obd/renault.dart';
import '../obd/transport.dart';
import '../services/app_state.dart';
import '../services/storage.dart';
import 'checklist.dart';
import 'serial_transport.dart';
import 'workbench.dart';

const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);

/// Saves text to Documents/LoganDoctor and returns the path.
Future<String> saveText(String name, String text) async {
  final dir = await appDataDir('LoganDoctor');
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
  final f = File('${dir.path}/${name}_$stamp');
  await f.writeAsString(text);
  return f.path;
}

void toast(BuildContext c, String msg) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

// =====================================================================
// Connect
// =====================================================================

class DesktopConnectPage extends StatefulWidget {
  const DesktopConnectPage({super.key});
  @override
  State<DesktopConnectPage> createState() => _DesktopConnectPageState();
}

class _DesktopConnectPageState extends State<DesktopConnectPage> {
  List<PortInfo> ports = [];
  String? selected;
  int baud = 38400;
  final tcp = TextEditingController(text: '127.0.0.1:35000');
  String? portError;

  void _refresh() {
    try {
      setState(() {
        ports = listSerialPorts();
        portError = null;
        if (selected == null || !ports.any((p) => p.name == selected)) {
          selected = ports.isEmpty ? null : ports.first.name;
        }
      });
    } catch (e) {
      setState(() => portError = 'مكتبة المنافذ مش شغالة: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final log = context.read<TrafficLog>();
    Future<ObdTransport> wrap(Future<ObdTransport> t) async => LoggingTransport(await t, log);

    return ListView(padding: const EdgeInsets.all(24), children: [
      _StatusCard(app: app),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('قارئ بلوتوث أو USB (منفذ COM)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('ويندوز: Settings ← Bluetooth ← Add device ← اختار OBDII (الباسورد 1234 أو 0000). '
                'بعد الإقران هيظهر منفذ COM ("Standard Serial over Bluetooth link"). لو ظهر منفذين، جرب الـ Outgoing.\n'
                'لينكس: sudo rfcomm bind 0 <عنوان القارئ> ← المنفذ /dev/rfcomm0.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            if (portError != null) Text(portError!, style: const TextStyle(color: Colors.red)),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'المنفذ', border: OutlineInputBorder()),
                  items: [
                    for (final p in ports)
                      DropdownMenuItem(
                        value: p.name,
                        child: Text('${p.isBluetooth ? '🔵 ' : ''}${p.name}  ${p.description}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => selected = v),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  initialValue: baud,
                  decoration: const InputDecoration(labelText: 'السرعة', border: OutlineInputBorder()),
                  items: [for (final b in [9600, 38400, 57600, 115200, 230400, 500000]) DropdownMenuItem(value: b, child: Text('$b'))],
                  onChanged: (v) => setState(() => baud = v!),
                ),
              ),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'تحديث المنافذ'),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: app.busy || selected == null ? null : () => app.connect(() => wrap(SerialTransport.open(selected!, baud: baud))),
                icon: const Icon(Icons.usb),
                label: const Text('وصّل'),
              ),
            ]),
            if (ports.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('مفيش منافذ. اعمل إقران للقارئ الأول.')),
            const Text('أغلب قارئات البلوتوث المقلدة: 38400. vLinker / OBDLink: 115200. لو مفيش رد جرّب سرعة تانية.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('قارئ Wi-Fi أو محاكي ELM327', style: Theme.of(context).textTheme.titleMedium),
            const Text('محاكي على نفس الجهاز: pip install ELM327-emulator ثم elm -n 35000', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: tcp, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'IP:Port', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: app.busy
                    ? null
                    : () {
                        final parts = tcp.text.trim().split(':');
                        app.connect(() => wrap(TcpTransport.connect(parts[0], int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 35000)));
                      },
                icon: const Icon(Icons.wifi),
                label: const Text('وصّل'),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (app.link) {
      LinkState.connected => (Colors.green, Icons.check_circle, 'متوصل: ${app.linkLabel}  •  بروتوكول ${app.obdElm?.protocol ?? '?'}'),
      LinkState.connecting => (Colors.orange, Icons.hourglass_top, app.busyAr),
      LinkState.disconnected => (Colors.grey, Icons.link_off, 'مش متوصل'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (app.link == LinkState.connected) OutlinedButton(onPressed: app.disconnect, child: const Text('افصل')),
          ]),
          if (app.reader != null)
            Text(app.reader!.messageAr,
                style: TextStyle(color: app.reader!.level == ReaderLevel.full ? Colors.green.shade800 : Colors.orange.shade900)),
          if (app.errorAr != null) Text(app.errorAr!, style: const TextStyle(color: Colors.red)),
        ]),
      ),
    );
  }
}

// =====================================================================
// Checklist (the 20 real-car checks)
// =====================================================================

class ChecklistPage extends StatelessWidget {
  const ChecklistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cl = context.watch<Checklist>();
    final wb = context.watch<Workbench>();
    final connected = context.watch<AppState>().link == LinkState.connected;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('قايمة التأكيد على العربية: ${cl.doneCount} من ${cl.items.length}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: cl.doneCount / cl.items.length),
            ]),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            onPressed: !connected || wb.busy
                ? null
                : () async {
                    for (final p in ['adapter', 'platform', 'modules', 'pids']) {
                      await wb.runProbe(p);
                    }
                  },
            icon: const Icon(Icons.playlist_play),
            label: const Text('شغّل كل الاختبارات التلقائية'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final path = await saveText('logan_checklist.md', cl.exportMarkdown());
              if (context.mounted) toast(context, 'اتحفظ: $path');
            },
            icon: const Icon(Icons.save_alt),
            label: const Text('صدّر التقرير'),
          ),
        ]),
      ),
      if (wb.busy || wb.status.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            if (wb.busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Expanded(child: Text(wb.status)),
          ]),
        ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [for (final i in cl.items) _CheckCard(item: i, connected: connected)]),
      ),
    ]);
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.item, required this.connected});
  final CheckItem item;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final wb = context.watch<Workbench>();
    final cl = context.read<Checklist>();
    final (icon, color) = switch (item.state) {
      CheckState.done => (Icons.check_circle, Colors.green),
      CheckState.problem => (Icons.error, Colors.orange),
      CheckState.todo => (Icons.radio_button_unchecked, Colors.grey),
    };
    final kindLabel = switch (item.kind) {
      CheckKind.auto => 'تلقائي',
      CheckKind.logger => 'تسجيل',
      CheckKind.ddt => 'ملف تعريف',
      CheckKind.manual => 'يدوي',
    };
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text('${item.id}. ${item.titleAr}'),
        subtitle: Text(item.result.isEmpty ? kindLabel : '$kindLabel  •  ${item.result.split('\n').first}', maxLines: 1, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.howAr),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (item.kind == CheckKind.auto || item.kind == CheckKind.ddt)
              if (item.probe.isNotEmpty)
                FilledButton.icon(
                  onPressed: (!connected && item.kind == CheckKind.auto) || wb.busy ? null : () => wb.runProbe(item.probe),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('شغّل الاختبار'),
                ),
            if (item.kind == CheckKind.logger) _LoggerControls(item: item, connected: connected),
            OutlinedButton(onPressed: () => cl.update(item.id, state: CheckState.done), child: const Text('تمام ✅')),
            OutlinedButton(onPressed: () => cl.update(item.id, state: CheckState.problem), child: const Text('في مشكلة ⚠️')),
            TextButton(onPressed: () => cl.update(item.id, state: CheckState.todo, result: ''), child: const Text('إعادة')),
          ]),
          if (item.result.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SelectableText(item.result, style: mono, textDirection: TextDirection.ltr),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            initialValue: item.notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظاتك / القيمة اللي قستها', border: OutlineInputBorder()),
            onChanged: (v) => cl.update(item.id, notes: v),
          ),
        ],
      ),
    );
  }
}

class _LoggerControls extends StatelessWidget {
  const _LoggerControls({required this.item, required this.connected});
  final CheckItem item;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final wb = context.watch<Workbench>();
    final mine = wb.loggerId == item.probe;
    final last = wb.samples.isEmpty ? null : wb.samples.last;
    if (!mine) {
      return FilledButton.icon(
        onPressed: !connected || wb.logging ? null : () => wb.startLogger(item.probe),
        icon: const Icon(Icons.fiber_manual_record),
        label: const Text('ابدأ التسجيل'),
      );
    }
    return Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Chip(
        avatar: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
        label: Text(item.probe == 'fan'
            ? 'الحرارة ${last?['$pidCoolant']?.toStringAsFixed(0) ?? '--'}°  •  ${last?['$pidRpm']?.toStringAsFixed(0) ?? '--'} لفة  •  ${wb.samples.length} ث'
            : 'قصير ${last?['6']?.toStringAsFixed(1) ?? '--'}%  •  طويل ${last?['7']?.toStringAsFixed(1) ?? '--'}%  •  ${wb.samples.length} ث'),
      ),
      if (item.probe == 'fan') ...[
        FilterChip(label: const Text('التكييف شغال'), selected: wb.acOn, onSelected: (v) => wb.acOn = v),
        FilledButton(onPressed: wb.markFan, child: const Text('المروحة اشتغلت دلوقتي')),
      ],
      if (item.probe == 'cng')
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'بنزين', label: Text('بنزين')), ButtonSegment(value: 'غاز', label: Text('غاز'))],
          selected: {wb.cngFuel},
          onSelectionChanged: (v) => wb.cngFuel = v.first,
        ),
      OutlinedButton(onPressed: wb.stopLogger, child: const Text('وقّف واحفظ')),
    ]);
  }
}

// =====================================================================
// Developer console: raw commands to the reader or any module
// =====================================================================

class ConsolePage extends StatefulWidget {
  const ConsolePage({super.key});
  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  RenaultModule? target; // null = generic OBD
  RenaultDiag? diag;
  final history = <String>[];
  String? error;
  bool sending = false;

  static const quickGeneric = ['ATI', 'ATRV', 'ATDPN', 'AT@1', '0100', '0101', '0105', '010C', '03', '07', '0A'];
  static const quickModule = ['10C0', '2180', '17FF00', '1902AF', '1003', '22F18A', '22F194', '3E00'];

  Future<void> _setTarget(AppState app, RenaultModule? m) async {
    final elm = app.obdElm;
    if (elm == null) return;
    app.stopMonitoring();
    setState(() => sending = true);
    try {
      if (m == null) {
        await diag?.backToObd();
        diag = null;
      } else {
        diag ??= RenaultDiag(elm);
        await diag!.select(m);
      }
      target = m;
      error = null;
    } on ObdException catch (e) {
      error = e.messageAr;
    } finally {
      setState(() => sending = false);
    }
  }

  Future<void> _send(AppState app, String cmd) async {
    cmd = cmd.trim().toUpperCase();
    if (cmd.isEmpty || app.obdElm == null) return;
    app.stopMonitoring();
    history.remove(cmd);
    history.insert(0, cmd);
    setState(() {
      sending = true;
      error = null;
    });
    try {
      if (target == null || cmd.startsWith('AT') || cmd.startsWith('ST')) {
        await app.obdElm!.send(cmd, timeout: const Duration(seconds: 10));
      } else {
        await diag!.raw(cmd, timeout: const Duration(seconds: 5));
      }
    } on ObdException catch (e) {
      error = e.messageAr;
    } catch (e) {
      error = '$e';
    } finally {
      setState(() => sending = false);
      input.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final log = context.watch<TrafficLog>();
    final connected = app.link == LinkState.connected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('بتكلم: '),
          const SizedBox(width: 8),
          DropdownButton<RenaultModule?>(
            value: target,
            items: [
              const DropdownMenuItem(value: null, child: Text('OBD عام (الموتور)')),
              for (final m in loganModules) DropdownMenuItem(value: m, child: Text('${m.nameAr}  ${m.tx}→${m.rx}')),
            ],
            onChanged: !connected || sending ? null : (m) => _setTarget(app, m),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () async {
              final path = await saveText('traffic.log', log.export());
              if (context.mounted) toast(context, 'اتحفظ: $path');
            },
            icon: const Icon(Icons.save_alt),
            label: const Text('احفظ اللوج'),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: log.clear, child: const Text('امسح')),
        ]),
        const Text('الأوامر اللي بتبرمج الكمبيوتر أو بتفتح الحماية (27، 2E، 31، 34-37، 3B، 3D، 28، 85) مقفولة حتى هنا.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            color: const Color(0xFF101418),
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              controller: scroll,
              itemCount: log.lines.length,
              itemBuilder: (_, i) {
                final l = log.lines[i];
                final t = '${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}:${l.time.second.toString().padLeft(2, '0')}';
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText('$t ${l.tx ? '>>' : '<<'} ${l.text}',
                      style: mono.copyWith(color: l.tx ? const Color(0xFF7FD1FF) : const Color(0xFFB8F2A0))),
                );
              },
            ),
          ),
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final q in target == null ? quickGeneric : quickModule)
            ActionChip(label: Text(q, style: mono), onPressed: !connected || sending ? null : () => _send(app, q)),
        ]),
        const SizedBox(height: 8),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: input,
                enabled: connected,
                style: mono,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: target == null ? 'ATI  /  010C  /  03' : 'service bytes, e.g. 2180 (length byte is added for you)',
                ),
                onSubmitted: (v) => _send(app, v),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: !connected || sending ? null : () => _send(app, input.text), child: const Text('Send')),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
// Live chart + CSV recorder
// =====================================================================

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});
  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  final hist = <int, List<double>>{};
  late final AppState app = context.read<AppState>();
  Set<int> shown = {pidCoolant, pidRpm};

  void _onLive() {
    for (final e in app.live.entries) {
      final l = hist.putIfAbsent(e.key, () => []);
      l.add(e.value);
      if (l.length > 400) l.removeAt(0);
    }
  }

  @override
  void initState() {
    super.initState();
    app.addListener(_onLive);
    app.showAllPids = true;
  }

  @override
  void dispose() {
    app.removeListener(_onLive);
    app.showAllPids = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AppState>();
    final wb = context.watch<Workbench>();
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.teal, Colors.brown, Colors.pink];
    final pids = a.livePidList;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          FilledButton.icon(
            onPressed: a.link != LinkState.connected ? null : () => a.monitoring ? setState(a.stopMonitoring) : a.startMonitoring(),
            icon: Icon(a.monitoring ? Icons.pause : Icons.play_arrow),
            label: Text(a.monitoring ? 'وقّف القراءة' : 'ابدأ القراءة'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: wb.toggleRecording,
            icon: Icon(Icons.fiber_manual_record, color: wb.recording ? Colors.red : null),
            label: Text(wb.recording ? 'بيسجل (${wb.recorded.length})' : 'سجّل CSV'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: wb.recorded.isEmpty
                ? null
                : () async {
                    final path = await saveText('live.csv', wb.exportCsv());
                    if (context.mounted) toast(context, 'اتحفظ: $path');
                  },
            icon: const Icon(Icons.save_alt),
            label: const Text('احفظ CSV'),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < pids.length; i++)
            FilterChip(
              avatar: CircleAvatar(backgroundColor: colors[i % colors.length], radius: 6),
              label: Text('${livePids[pids[i]]!.nameAr}: ${a.live[pids[i]]?.toStringAsFixed(1) ?? '--'} ${livePids[pids[i]]!.unit}'),
              selected: shown.contains(pids[i]),
              onSelected: (v) => setState(() => v ? shown.add(pids[i]) : shown.remove(pids[i])),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: CustomPaint(
              painter: _LinesPainter({
                for (var i = 0; i < pids.length; i++)
                  if (shown.contains(pids[i])) colors[i % colors.length]: (hist[pids[i]] ?? const <double>[], livePids[pids[i]]!),
              }),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const Text('كل خط متعاير على مداه (مثلًا الحرارة من -40 لـ 130). الأرقام الحقيقية في الشرايح فوق.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter(this.series);
  final Map<Color, (List<double>, PidDef)> series;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.grey.withValues(alpha: 0.2);
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), grid);
    }
    for (final e in series.entries) {
      final (vals, def) = e.value;
      if (vals.length < 2) continue;
      final path = Path();
      for (var i = 0; i < vals.length; i++) {
        final x = size.width * i / 399;
        final y = size.height * (1 - ((vals[i] - def.min) / (def.max - def.min)).clamp(0.0, 1.0));
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, Paint()
        ..color = e.key
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
