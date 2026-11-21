import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/dtc_repo.dart';
import '../data/models.dart';
import '../obd/bt_transport.dart';
import '../obd/elm327.dart';
import '../obd/pids.dart';
import '../obd/transport.dart';
import 'alerts.dart';
import 'history_repo.dart';
import 'safety.dart';

enum LinkState { disconnected, connecting, connected }

/// Single app-wide controller (exposed with Provider).
class AppState extends ChangeNotifier {
  AppState({required this.dtc, HistoryRepo? history, this.notifier})
      : history = history ?? HistoryRepo();

  final DtcRepo dtc;
  final HistoryRepo history;

  /// Sends phone notifications; null in tests.
  final Future<void> Function(Alert a)? notifier;

  final safety = SafetyGuard();
  final alerts = AlertEngine();

  LinkState link = LinkState.disconnected;
  String? linkLabel;
  String? errorAr;
  ReaderReport? reader;
  Elm327? _elm;
  ObdService? obd;
  Elm327? get obdElm => _elm;

  ScanResult? lastScan;
  bool busy = false;
  String busyAr = '';

  final live = <int, double>{};
  double? readerVolts;
  Timer? _monitor;
  bool monitoring = false;
  int _tick = 0;
  final List<Alert> recentAlerts = [];

  /// Engine module only in Phase 1. ABS / airbag / body come in Phase 3.
  static const expectedModules = ['كمبيوتر الموتور'];

  // ---------------- Connection ----------------

  Future<void> connect(Future<ObdTransport> Function() open) async {
    await disconnect();
    link = LinkState.connecting;
    errorAr = null;
    _setBusy('بنوصل بالقارئ...');
    try {
      final t = await open();
      linkLabel = t.label;
      _elm = Elm327(t);
      _setBusy('بنختبر القارئ...');
      reader = await _elm!.checkReader();
      _setBusy('بنكلم كمبيوتر العربية...');
      await _elm!.init();
      obd = ObdService(_elm!);
      await obd!.loadSupportedPids();
      link = LinkState.connected;
    } on ObdException catch (e) {
      errorAr = e.messageAr;
      await disconnect(keepError: true);
    } catch (e) {
      errorAr = 'مش قادرين نوصل بالقارئ. اتأكد إنه متوصل في فيشة OBD تحت الدركسيون والكونتاكت شغال. ($e)';
      await disconnect(keepError: true);
    }
    _done();
  }

  Future<void> disconnect({bool keepError = false}) async {
    stopMonitoring();
    try {
      await _elm?.dispose();
    } catch (_) {}
    _elm = null;
    obd = null;
    link = LinkState.disconnected;
    if (!keepError) errorAr = null;
    notifyListeners();
  }

  // ---------------- Scan ----------------

  Future<ScanResult?> scan({String note = ''}) async {
    final o = obd;
    if (o == null) return null;
    _setBusy('بنقرا الأعطال...');
    try {
      final codes = <FoundCode>[];
      final answered = <String>{};
      for (final (status, fn) in [
        (DtcStatus.stored, o.storedCodes),
        (DtcStatus.pending, o.pendingCodes),
        (DtcStatus.permanent, o.permanentCodes),
      ]) {
        final byEcu = await fn();
        for (final e in byEcu.entries) {
          final module = moduleNameAr(e.key);
          answered.add(module);
          for (final c in e.value) {
            if (!codes.any((x) => x.code == c && x.status == status)) codes.add(FoundCode(c, status, module));
          }
        }
      }
      final mil = await o.monitorStatus();
      if (mil != null) answered.add(moduleNameAr(_elm!.isCan ? engineEcuCan : '10'));
      _setBusy('بنقرا الـ Freeze Frame...');
      final ff = codes.isEmpty ? <String, Object>{} : await o.freezeFrame();
      readerVolts = await _elm!.readerVoltage();

      codes.sort((a, b) => dtc.lookup(a.code).severity.rank.compareTo(dtc.lookup(b.code).severity.rank));
      final r = ScanResult(
        time: DateTime.now(),
        codes: codes,
        milOn: mil?.milOn ?? false,
        modulesAnswered: answered.toList(),
        modulesSilent: expectedModules.where((m) => !answered.contains(m)).toList(),
        freezeFrame: ff,
        batteryVolts: readerVolts,
        note: note,
      );
      lastScan = r;
      await history.save(r);
      return r;
    } on ObdException catch (e) {
      errorAr = e.messageAr;
      return null;
    } finally {
      _done();
    }
  }

  // ---------------- Clear (write: guarded) ----------------

  /// Returns null on success, or an Arabic reason it was blocked / failed.
  /// The UI must already have shown [SafetyGuard.clearWarningAr] and a second confirm.
  Future<String?> clearCodes() async {
    final o = obd;
    if (o == null) return 'مش متوصل.';
    _setBusy('بنتأكد إن العربية واقفة...');
    try {
      final speed = await o.readPid(pidSpeed);
      final d = safety.canWrite(speedKmh: speed);
      if (!d.allowed) return d.reasonAr;
      if (lastScan != null) await history.save(lastScan!); // keep the proof
      _setBusy('بنمسح الأكواد...');
      final ok = await o.clearCodes();
      if (!ok) return 'كمبيوتر الموتور رفض المسح. جرب والكونتاكت شغال والموتور مطفي.';
      await scan(note: 'بعد المسح');
      return null;
    } on ObdException catch (e) {
      return e.messageAr;
    } finally {
      _done();
    }
  }

  // ---------------- Live data + alerts ----------------

  List<int> get livePidList => livePids.keys
      .where((p) => obd == null || obd!.supported.isEmpty || obd!.supported.contains(p))
      .toList();

  void startMonitoring() {
    if (monitoring || obd == null) return;
    monitoring = true;
    if (notifier != null) NativeBt.startMonitorService().catchError((_) {});
    _monitor = Timer.periodic(const Duration(milliseconds: 1500), (_) => _poll());
    notifyListeners();
  }

  void stopMonitoring() {
    _monitor?.cancel();
    _monitor = null;
    if (monitoring && notifier != null) NativeBt.stopMonitorService().catchError((_) {});
    monitoring = false;
  }

  bool _polling = false;
  bool showAllPids = false;

  Future<void> _poll() async {
    final o = obd;
    if (o == null || _polling) return;
    _polling = true;
    try {
      _tick++;
      // Always: the alert-critical values. Others only when the live screen asks.
      final pids = showAllPids ? livePidList : [pidCoolant, pidRpm, pidSpeed];
      for (final p in pids) {
        final v = await o.readPid(p);
        if (v != null) live[p] = v;
      }
      readerVolts = await _elm!.readerVoltage() ?? readerVolts;

      bool? mil;
      Set<String>? codes;
      if (_tick % 40 == 1) {
        // About once a minute: Check Engine state and new codes.
        mil = (await o.monitorStatus())?.milOn;
        codes = {
          ...(await o.storedCodes()).values.expand((e) => e),
          ...(await o.pendingCodes()).values.expand((e) => e),
        };
      }
      final fired = alerts.feed(Reading(
        coolantC: live[pidCoolant],
        volts: readerVolts,
        rpm: live[pidRpm],
        speed: live[pidSpeed],
        milOn: mil,
        codes: codes,
      ));
      for (final a in fired) {
        recentAlerts.insert(0, a);
        await notifier?.call(a);
      }
      notifyListeners();
    } on ObdException catch (e) {
      errorAr = e.messageAr;
      notifyListeners();
    } catch (_) {
      // Link dropped: cheap clones do this. Stop and tell the user.
      errorAr = 'الاتصال بالقارئ اتقطع. ده بيحصل كتير مع القارئات المقلدة. وصّل تاني.';
      await disconnect(keepError: true);
    } finally {
      _polling = false;
    }
  }

  Map<String, double> liveSnapshot() => {
        for (final e in live.entries) livePids[e.key]!.nameAr: e.value,
        if (readerVolts != null) 'فولت البطارية': readerVolts!,
      };

  void _setBusy(String s) {
    busy = true;
    busyAr = s;
    notifyListeners();
  }

  void _done() {
    busy = false;
    busyAr = '';
    notifyListeners();
  }
}
