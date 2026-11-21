import 'dart:io';

import 'package:flutter/foundation.dart';

import '../obd/ddt.dart';
import '../obd/elm327.dart';
import '../obd/obd_parser.dart';
import '../obd/renault.dart';
import 'app_state.dart';
import 'safety.dart';
import 'storage.dart';

/// "Every computer in the car" mode: scan all Logan II modules, read every
/// parameter an imported definition file describes, and run guarded
/// actuator tests (e.g. cooling fan on / off).
class RenaultController extends ChangeNotifier {
  RenaultController(this.app);
  final AppState app;
  final safety = SafetyGuard();

  final scans = <String, ModuleScan>{}; // by diag address
  final ecus = <String, DdtEcu>{}; // imported definitions, by diag address
  final values = <String, String>{}; // last read: "request/item" -> value
  bool busy = false;
  String status = '';
  String? errorAr;

  // Actuator test in progress.
  DdtRequest? activeTest;
  int secondsLeft = 0;

  /// Modules where control is never offered (brakes, airbag, steering).
  static const noControlModules = {'01', '2C', '04'};

  RenaultDiag? get _diag => app.obdElm == null ? null : RenaultDiag(app.obdElm!);

  Future<void> loadSavedDefinitions() async {
    final Directory dir;
    try {
      dir = await _defsDir();
    } catch (_) {
      return;
    }
    for (final f in dir.listSync().whereType<File>()) {
      final addr = f.uri.pathSegments.last.split('.').first;
      try {
        ecus[addr] = DdtEcu.fromJson(await f.readAsString());
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<Directory> _defsDir() => appDataDir('LoganDoctor/ecu_defs');

  /// Imports a DDT4ALL-format JSON for one module (the owner's own file).
  Future<String?> importDefinition(RenaultModule m, String json) async {
    try {
      final e = DdtEcu.fromJson(json);
      if (e.recvId.isNotEmpty && e.recvId != m.rx) {
        return 'الملف ده لموديول ردّه ${e.recvId}، مش ${m.rx}. اتأكد إنك اخترت الملف الصح.';
      }
      ecus[m.diagAddr] = e;
      await File('${(await _defsDir()).path}/${m.diagAddr}.json').writeAsString(json);
      notifyListeners();
      return null;
    } catch (e) {
      return 'الملف مش بصيغة DDT4ALL JSON: $e';
    }
  }

  Future<T?> _run<T>(String what, Future<T> Function(RenaultDiag d) body) async {
    final d = _diag;
    if (d == null) {
      errorAr = 'وصّل القارئ الأول.';
      notifyListeners();
      return null;
    }
    app.stopMonitoring(); // one user of the reader at a time
    busy = true;
    status = what;
    errorAr = null;
    notifyListeners();
    try {
      return await body(d);
    } on ObdException catch (e) {
      errorAr = e.messageAr;
      return null;
    } finally {
      try {
        await d.backToObd();
      } catch (_) {}
      busy = false;
      status = '';
      notifyListeners();
    }
  }

  Future<void> scanAll() => _run('بنكلم كل كمبيوترات العربية...', (d) async {
        for (final m in loganModules) {
          status = 'بنكلم ${m.nameAr}...';
          notifyListeners();
          try {
            scans[m.diagAddr] = await d.scan(m);
          } on ObdException {
            scans[m.diagAddr] = ModuleScan(m);
          }
          notifyListeners();
        }
      });

  /// Name of a fault from the imported definition (DTC request lists), if any.
  String? dtcName(RenaultModule m, RawDtc c) {
    final e = ecus[m.diagAddr];
    if (e == null) return null;
    for (final d in e.data.values) {
      if (d.lists.containsKey(c.code) && d.name.toUpperCase().contains('DTC')) return d.lists[c.code];
    }
    return null;
  }

  Future<String?> clearModule(RenaultModule m) async {
    final s = scans[m.diagAddr];
    // Airbag: never clear while a "computer / crash stored" fault is present.
    if (m.diagAddr == '2C' && (s?.dtcs.any((c) => c.code == 0x001 || c.code == 0x194 || c.code == 0x034) ?? false)) {
      return 'في عطل "كمبيوتر الإيرباج / تسجيل حادثة". ده مش بيتمسح، والإيرباج غالبًا مش هيفتح. لازم مركز متخصص.';
    }
    return _run('بنمسح أعطال ${m.nameAr}...', (d) async {
      final speed = await _speed(d);
      final ok = safety.canWrite(speedKmh: speed);
      if (!ok.allowed) return ok.reasonAr;
      if (!await d.clear(m, uds: s?.uds ?? false)) return '${m.nameAr} رفض المسح.';
      scans[m.diagAddr] = await d.scan(m);
      return null;
    }).then((v) => v ?? errorAr);
  }

  /// Vehicle speed from the engine ECU (Mode 01 PID 0D over raw CAN).
  Future<double?> _speed(RenaultDiag d) async {
    await d.select(loganModules.first);
    final r = await d.raw('010D');
    return (r != null && r.length >= 3 && r[0] == 0x41 && r[1] == 0x0D) ? r[2].toDouble() : null;
  }

  Future<double?> _rpm(RenaultDiag d) async {
    await d.select(loganModules.first);
    final r = await d.raw('010C');
    return (r != null && r.length >= 4 && r[0] == 0x41) ? (r[2] * 256 + r[3]) / 4 : null;
  }

  /// Reads every parameter the module's definition describes.
  Future<void> readAll(RenaultModule m) async {
    final e = ecus[m.diagAddr];
    if (e == null) return;
    await _run('بنقرا كل حساسات ${m.nameAr}...', (d) async {
      await d.select(m);
      await d.raw('10C0');
      var since = DateTime.now();
      for (final r in e.readRequests) {
        if (DateTime.now().difference(since).inSeconds >= 3) {
          await d.raw('10C0'); // keep the session open (pyren does it every 4 s)
          since = DateTime.now();
        }
        if (r.sent.length > 14) continue;
        final reply = await d.raw(r.sent);
        if (reply == null || reply.isEmpty || reply[0] == 0x7F) continue;
        for (final it in r.recvItems) {
          final v = e.display(reply, it);
          if (v != null) values['${m.diagAddr}/${it.name}'] = v;
        }
        notifyListeners();
      }
    });
  }

  /// Runs an actuator test for [seconds] (max 30), then hands control back.
  Future<String?> runTest(RenaultModule m, DdtRequest r, Map<String, int> rawValues, {int seconds = 10}) async {
    if (noControlModules.contains(m.diagAddr)) return 'التحكم في ${m.nameAr} ممنوع في التطبيق للأمان.';
    if (r.kind != DdtKind.control) return 'ده مش أمر اختبار.';
    final e = ecus[m.diagAddr]!;
    final bytes = e.buildSend(r, rawValues);
    final payload = hex(bytes).replaceAll(' ', '');
    if (safety.isForbiddenCommand(payload)) return 'الأمر ده ممنوع.';
    final stop = DdtEcu.stopCommandFor(r);
    seconds = seconds.clamp(2, 30);

    return _run('اختبار: ${r.name}', (d) async {
      final speed = await _speed(d);
      final ok = safety.canWrite(speedKmh: speed);
      if (!ok.allowed) return ok.reasonAr;
      final rpm = await _rpm(d);
      if ((rpm ?? 0) > 0 && m.diagAddr == '7A') {
        return 'اطفي الموتور (سيب الكونتاكت شغال) قبل اختبارات كمبيوتر الموتور.';
      }
      await d.select(m);
      await d.raw('10C0');
      final res = await d.raw(payload);
      if (!RenaultDiag.positive(res, int.parse(r.service, radix: 16))) {
        return 'الكمبيوتر رفض الأمر (${res == null ? 'مفيش رد' : hex(res)}).';
      }
      activeTest = r;
      try {
        for (secondsLeft = seconds; secondsLeft > 0; secondsLeft--) {
          notifyListeners();
          await Future<void>.delayed(const Duration(seconds: 1));
          if (secondsLeft % 3 == 0) await d.raw('10C0'); // tester present
          if (activeTest == null) break; // user pressed stop
        }
      } finally {
        // Always hand control back, even if the link hiccups mid-test.
        if (stop.isNotEmpty) await d.raw(stop).catchError((_) => null);
        activeTest = null;
      }
      return null;
    }).then((v) => v ?? errorAr);
  }

  /// Lets other screens (desktop workbench) tell listeners that scans changed.
  void refresh() => notifyListeners();

  void stopTest() {
    activeTest = null;
    notifyListeners();
  }
}
