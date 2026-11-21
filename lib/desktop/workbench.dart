import 'dart:async';

import 'package:flutter/foundation.dart';

import '../obd/elm327.dart';
import '../obd/obd_parser.dart';
import '../obd/pids.dart';
import '../obd/renault.dart';
import '../services/app_state.dart';
import '../services/renault_controller.dart';
import 'checklist.dart';
import 'serial_transport.dart';

/// Desktop "workbench": the automatic probes behind the real-car checklist,
/// the fan / CNG loggers, and a CSV recorder for live data.
class Workbench extends ChangeNotifier {
  Workbench(this.app, this.renault, this.checklist, this.log) {
    app.addListener(_onLive);
  }

  final AppState app;
  final RenaultController renault;
  final Checklist checklist;
  final TrafficLog log;

  bool busy = false;
  String status = '';

  Elm327 get _elm {
    final e = app.obdElm;
    if (e == null) throw ObdException('وصّل القارئ الأول.');
    return e;
  }

  Future<void> _run(String what, Future<void> Function() body) async {
    if (busy) return;
    app.stopMonitoring();
    busy = true;
    status = what;
    notifyListeners();
    try {
      await body();
    } on ObdException catch (e) {
      status = e.messageAr;
    } catch (e) {
      status = 'خطأ: $e';
    } finally {
      busy = false;
      if (status == what) status = '';
      notifyListeners();
    }
  }

  Future<void> runProbe(String probe) => switch (probe) {
        'platform' => probePlatform(),
        'modules' => probeModules(),
        'pids' => probePids(),
        'adapter' => probeAdapter(),
        'ddt_dtc' || 'ddt_control' => probeDdt(),
        _ => Future.value(),
      };

  // ---------- Items 2, 3, 4, 5, 14: every module ----------

  Future<void> probeModules() => _run('بنكلم كل عناوين لوجان 2...', () async {
        final d = RenaultDiag(_elm);
        final lines = <String>[];
        final idents = <String>[];
        final dtcLines = <String>[];
        for (final m in loganModules) {
          status = 'بنجرب ${m.nameAr} (${m.tx})...';
          notifyListeners();
          var s = await _safeScan(d, m, 6);
          var speed = '500k';
          if (!s.answered) {
            s = await _safeScan(d, m, 8);
            speed = '250k';
          }
          renault.scans[m.diagAddr] = s;
          if (!s.answered) {
            lines.add('✗ ${m.tx}/${m.rx} ${m.nameAr}: مردش');
            continue;
          }
          lines.add('✓ ${m.tx}/${m.rx} ${m.nameAr} @ $speed ${s.uds ? 'UDS' : 'KWP'}');
          var ident = s.identHex;
          if (s.uds) {
            for (final did in ['22F194', '22F195']) {
              final r = await d.raw(did).catchError((_) => null);
              if (r != null) ident += ' | ${hex(r)}';
            }
          }
          idents.add('${m.nameAr}: $ident  (ASCII: ${_ascii(ident)})');
          dtcLines.add('${m.nameAr}: ${s.uds ? '1902AF' : '17FF00'} → ${s.dtcs.isEmpty ? 'مفيش أعطال' : s.dtcs.map((c) => '${c.label}/${c.status.toRadixString(16)}').join(' ')}');
        }
        await d.backToObd();
        final engine = renault.scans['7A'];
        checklist.update(2,
            state: idents.isEmpty ? CheckState.problem : CheckState.done, result: lines.join('\n'));
        checklist.update(3,
            state: engine?.answered == true ? CheckState.done : CheckState.problem,
            result: engine?.answered == true
                ? idents.where((l) => l.startsWith('كمبيوتر الموتور')).join('\n')
                : 'كمبيوتر الموتور مردش على 10C0 (جلسة رينو). OBD العادي ممكن يكون شغال.');
        final others = idents.where((l) => !l.startsWith('كمبيوتر الموتور')).toList();
        checklist.update(4,
            state: others.isEmpty ? CheckState.problem : CheckState.done,
            result: others.isEmpty ? 'مفيش كمبيوتر رد غير الموتور (أو ولا واحد). جرّب قارئ v1.5 أو vLinker.' : others.join('\n'));
        checklist.update(5,
            state: dtcLines.isEmpty ? CheckState.problem : CheckState.done,
            result: dtcLines.isEmpty ? 'مفيش كمبيوتر رد على أوامر رينو.' : dtcLines.join('\n'));
        final eps = renault.scans['04']?.answered == true;
        checklist.update(14, result: eps ? 'العنوان 742 رد: في دركسيون كهربا' : 'العنوان 742 مردش: غالبًا دركسيون هيدروليك بسير');
        renault.refresh();
      });

  Future<ModuleScan> _safeScan(RenaultDiag d, RenaultModule m, int protocol) async {
    try {
      return await d.scan(m, protocol: protocol);
    } on ObdException {
      return ModuleScan(m);
    }
  }

  String _ascii(String hexStr) {
    final bytes = RegExp(r'[0-9A-F]{2}').allMatches(hexStr).map((m) => int.parse(m.group(0)!, radix: 16));
    return String.fromCharCodes(bytes.map((b) => b >= 32 && b < 127 ? b : 46));
  }

  // ---------- Item 1: platform (CAN address table + K-line) ----------

  Future<void> probePlatform() => _run('بنحدد جيل العربية...', () async {
        final d = RenaultDiag(_elm);
        var canCount = 0;
        for (final m in loganModules.take(5)) {
          if ((await _safeScan(d, m, 6)).answered) canCount++;
        }
        await d.backToObd();
        // K-line (pin 7): ISO 14230 fast init, then ISO 9141 slow init.
        var kline = 'مفيش رد على K-line';
        for (final p in ['ATSP5', 'ATSP4']) {
          await _elm.send(p);
          final r = await _elm.send('0100', timeout: const Duration(seconds: 12)).catchError((_) => 'NO DATA');
          if (!isNoData(r)) {
            kline = 'K-line رد على $p';
            break;
          }
        }
        await _elm.send('ATSP0');
        await _elm.send('0100', timeout: const Duration(seconds: 12)).catchError((_) => '');
        final isX52 = canCount >= 2;
        checklist.update(1,
            state: isX52 ? CheckState.done : CheckState.problem,
            result: '$canCount من 5 كمبيوترات أساسية ردّت على عناوين لوجان 2 (CAN)\n$kline\n'
                '${isX52 ? 'النتيجة: غالبًا لوجان 2 (X52)' : 'النتيجة: غالبًا لوجان 1 (X90) أو القارئ مش بيدعم أوامر رينو'}');
      });

  // ---------- Item 7: supported PIDs ----------

  Future<void> probePids() => _run('بنسأل الموتور عن القراءات المتاحة...', () async {
        final obd = app.obd ?? ObdService(_elm);
        await obd.loadSupportedPids();
        final sup = obd.supported.toList()..sort();
        final out = StringBuffer('PIDs: ${sup.map((p) => p.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}\n');
        final std = await _elm.request('011C');
        if (std.isNotEmpty && std.first.data.length >= 3) {
          out.writeln('011C (المعيار): ${_obdStandard(std.first.data[2])}');
        }
        final o2 = await _elm.request('0113');
        if (o2.isNotEmpty && o2.first.data.length >= 3) {
          final b = o2.first.data[2];
          out.writeln('0113 حساسات الأكسجين: ${b.toRadixString(2).padLeft(8, '0')} '
              '(${(b & 0x02) != 0 ? 'في حساس خلفي' : 'مفيش حساس خلفي'})');
        }
        out.writeln('PID 42 (فولت الكمبيوتر): ${sup.contains(0x42) ? 'موجود' : 'مش موجود → بنستخدم ATRV'}');
        checklist.update(7, state: CheckState.done, result: out.toString().trim());
      });

  String _obdStandard(int v) => switch (v) {
        1 => 'OBD-II (CARB)',
        2 => 'OBD (EPA)',
        3 => 'OBD + OBD-II',
        6 => 'EOBD (أوروبي)',
        7 => 'EOBD + OBD-II',
        9 => 'EOBD + OBD',
        13 => 'JOBD',
        _ => 'كود $v',
      };

  // ---------- Item 18: adapter capability ----------

  Future<void> probeAdapter() => _run('بنختبر القارئ...', () async {
        final cmds = {
          'ATI': 'الإصدار',
          'AT@1': 'الوصف',
          'STI': 'شريحة STN (vLinker/OBDLink)',
          'ATRV': 'فولت البطارية',
          'ATDPN': 'رقم البروتوكول',
          'ATCAF0': 'إطفاء التنسيق التلقائي',
          'ATCAF1': 'تشغيل التنسيق التلقائي',
          'ATSH7E0': 'تغيير العنوان',
          'ATCRA7E8': 'فلتر الاستقبال',
          'ATCRA': 'إلغاء الفلتر',
          'ATFCSH7E0': 'عنوان Flow control (ضروري لرينو)',
          'ATFCSD300000': 'بيانات Flow control',
          'ATFCSM1': 'وضع Flow control',
          'ATFCSM0': 'رجوع Flow control',
          'ATCFC0': 'إطفاء Flow control',
          'ATCFC1': 'تشغيل Flow control',
          'ATST64': 'مهلة الرد',
          'ATAT1': 'توقيت تلقائي',
          'ATPPS': 'إعدادات قابلة للبرمجة',
        };
        final out = StringBuffer();
        var missing = 0;
        for (final e in cmds.entries) {
          final r = await _elm.send(e.key).catchError((_) => 'TIMEOUT');
          final ok = !r.contains('?') && !r.contains('TIMEOUT');
          if (!ok && e.key != 'STI') missing++;
          out.writeln('${ok ? '✓' : '✗'} ${e.key.padRight(13)} ${e.value}: ${cleanLines(r).join(' ')}');
        }
        await _elm.init(); // put everything back
        checklist.update(18,
            state: missing == 0 ? CheckState.done : CheckState.problem,
            result: '${missing == 0 ? 'القارئ ده بيدعم كل اللي التطبيق محتاجه' : '$missing أمر مش مدعوم: كلام كمبيوترات رينو غالبًا مش هيشتغل'}\n$out'
                .trim());
      });

  // ---------- Items 6, 9, 10: from imported DDT definitions ----------

  Future<void> probeDdt() async {
    final dtc = StringBuffer();
    final ctl = StringBuffer();
    final rz = StringBuffer();
    for (final m in loganModules) {
      final e = renault.ecus[m.diagAddr];
      if (e == null) continue;
      final dtcLists = e.data.values.where((d) => d.name.toUpperCase().contains('DTC') && d.lists.isNotEmpty);
      final codes = dtcLists.fold<int>(0, (n, d) => n + d.lists.length);
      dtc.writeln('${m.nameAr} (${e.name}): $codes تعريف عطل');
      for (final r in e.controlRequests) {
        ctl.writeln('${m.nameAr}: ${r.name}  [${r.sent}]');
      }
      for (final r in e.requests.where((r) => RegExp(r'RZ|reset|init|apprent|adapt', caseSensitive: false).hasMatch(r.name))) {
        rz.writeln('${m.nameAr}: ${r.name}  [${r.sent}] ${r.kind.name}');
      }
    }
    if (dtc.isEmpty) {
      status = 'مفيش ملفات تعريف محمّلة. حمّلها من صفحة "الكمبيوترات".';
      notifyListeners();
      return;
    }
    checklist.update(6, state: CheckState.done, result: dtc.toString().trim());
    checklist.update(9, state: CheckState.done, result: ctl.isEmpty ? 'مفيش أوامر تحكم في الملفات' : ctl.toString().trim());
    checklist.update(10, result: rz.isEmpty ? 'مفيش أوامر تصفير ظاهرة بالاسم' : rz.toString().trim());
  }

  // ---------- Loggers: item 8 (fan) and item 19 (CNG) ----------

  Timer? _logTimer;
  String? loggerId; // 'fan' | 'cng'
  bool acOn = false;
  String cngFuel = 'بنزين';
  final samples = <Map<String, double>>[];
  final events = <String>[];

  bool get logging => _logTimer != null;

  void startLogger(String id) {
    if (logging || app.obd == null) return;
    app.stopMonitoring();
    loggerId = id;
    samples.clear();
    events.clear();
    final pids = id == 'fan' ? [pidCoolant, pidRpm] : [0x06, 0x07, pidRpm];
    var running = false;
    _logTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (running) return;
      running = true;
      try {
        final row = <String, double>{};
        for (final p in pids) {
          final v = await app.obd!.readPid(p);
          if (v != null) row['$p'] = v;
        }
        samples.add(row);
        notifyListeners();
      } catch (_) {
      } finally {
        running = false;
      }
    });
    notifyListeners();
  }

  void markFan() {
    final t = samples.isEmpty ? null : samples.last['$pidCoolant'];
    events.add('المروحة اشتغلت على ${t?.toStringAsFixed(0) ?? '?'}°م (التكييف ${acOn ? 'شغال' : 'مقفول'})');
    notifyListeners();
  }

  void stopLogger() {
    _logTimer?.cancel();
    _logTimer = null;
    if (loggerId == 'fan') {
      final temps = samples.map((s) => s['$pidCoolant']).whereType<double>();
      final idle = samples.map((s) => s['$pidRpm']).whereType<double>().where((r) => r > 400);
      checklist.update(8,
          state: events.isEmpty ? CheckState.todo : CheckState.done,
          appendResult: true,
          result: [
            ...events,
            if (temps.isNotEmpty) 'أعلى حرارة: ${temps.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}°م',
            if (idle.isNotEmpty) 'متوسط الرالنتي: ${(idle.reduce((a, b) => a + b) / idle.length).toStringAsFixed(0)} لفة',
          ].join('\n'));
    } else if (loggerId == 'cng') {
      double avg(int pid) {
        final v = samples.map((s) => s['$pid']).whereType<double>().toList();
        return v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;
      }

      checklist.update(19,
          state: CheckState.done,
          appendResult: true,
          result: 'على $cngFuel: تصحيح قصير ${avg(0x06).toStringAsFixed(1)}%، طويل ${avg(0x07).toStringAsFixed(1)}% (${samples.length} قراية)');
    }
    loggerId = null;
    notifyListeners();
  }

  // ---------- CSV recorder for live data ----------

  bool recording = false;
  final recorded = <List<String>>[];

  void toggleRecording() {
    recording = !recording;
    if (recording) recorded.clear();
    notifyListeners();
  }

  void _onLive() {
    if (!recording || app.live.isEmpty) return;
    recorded.add([
      DateTime.now().toIso8601String(),
      for (final p in livePids.keys) app.live[p]?.toStringAsFixed(2) ?? '',
      app.readerVolts?.toStringAsFixed(2) ?? '',
    ]);
  }

  String exportCsv() => [
        ['time', ...livePids.values.map((d) => '${d.command} ${d.unit}'), 'battery V'].join(','),
        ...recorded.map((r) => r.join(',')),
      ].join('\n');

  @override
  void dispose() {
    app.removeListener(_onLive);
    _logTimer?.cancel();
    super.dispose();
  }
}
