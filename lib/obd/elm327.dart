import 'dart:async';
import 'dart:convert';

import '../services/safety.dart';
import 'obd_parser.dart';
import 'pids.dart';
import 'transport.dart';

/// What the reader can really do, found by the check on first connect.
enum ReaderLevel { full, basic, unknown }

class ReaderReport {
  ReaderReport({required this.version, required this.level, required this.failed});
  final String version;
  final ReaderLevel level;
  final List<String> failed;

  String get messageAr => switch (level) {
        ReaderLevel.full => 'القارئ ($version) شغال كويس: كل المزايا متاحة.',
        ReaderLevel.basic =>
          'القارئ ده ($version) غالبًا نسخة مقلدة: هيقرا أكواد الموتور بس، وممكن يفصل. '
              'ننصح بقارئ ELM327 v1.5 بشريحة PIC18F25K80.',
        ReaderLevel.unknown => 'مش قادرين نحدد نوع القارئ.',
      };
}

class ObdException implements Exception {
  ObdException(this.messageAr);
  final String messageAr;
  @override
  String toString() => messageAr;
}

/// Low-level ELM327 driver: one command at a time, waits for the `>` prompt.
class Elm327 {
  Elm327(this.transport) {
    _sub = transport.input.listen(_onData);
  }

  final ObdTransport transport;
  late final StreamSubscription<List<int>> _sub;
  final _buf = StringBuffer();
  Completer<String>? _pending;
  Future<void> _queue = Future.value();

  int protocol = 0;

  /// True while AT CAF0 is active (Renault module mode): commands carry a length byte.
  bool rawFrames = false;
  bool get isCan => isCanProtocol(protocol);

  void _onData(List<int> bytes) {
    _buf.write(latin1.decode(bytes, allowInvalid: true));
    final s = _buf.toString();
    if (s.contains('>')) {
      _buf.clear();
      final p = _pending;
      _pending = null;
      p?.complete(s);
    }
  }

  /// Sends one command and returns the raw reply. Commands are serialised.
  Future<String> send(String cmd, {Duration timeout = const Duration(seconds: 4)}) {
    final up = cmd.replaceAll(' ', '').toUpperCase();
    if (up == 'ATCAF0') rawFrames = true;
    if (up == 'ATCAF1' || up == 'ATZ' || up == 'ATD' || up == 'ATWS') rawFrames = false;
    if (SafetyGuard().isForbiddenCommand(cmd, rawFrame: rawFrames)) {
      return Future.error(ObdException('الأمر ده ممنوع في التطبيق لأنه بيبرمج كمبيوتر العربية.'));
    }
    final result = _queue.then((_) async {
      _pending = Completer<String>();
      await transport.write(ascii.encode('$cmd\r'));
      try {
        return await _pending!.future.timeout(timeout);
      } on TimeoutException {
        _pending = null;
        throw ObdException('القارئ مردّش على الأمر $cmd. اتأكد إن الكونتاكت شغال والقارئ متوصل كويس.');
      }
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> _ok(String cmd) async {
    try {
      final r = await send(cmd);
      return r.contains('OK') || (!r.contains('?') && !r.toUpperCase().contains('ERROR'));
    } on ObdException {
      return false;
    }
  }

  /// Reader check: version + commands that cheap v2.1 clones often lack.
  Future<ReaderReport> checkReader() async {
    await send('ATZ', timeout: const Duration(seconds: 5));
    await send('ATE0');
    final ver = cleanLines(await send('ATI')).join(' ').trim();
    final failed = <String>[];
    for (final c in ['ATDPN', 'ATRV', 'ATCAF0', 'ATCAF1', 'ATSH7E0', 'ATCRA7E8', 'ATCRA', 'ATFCSM0', 'ATPPS']) {
      if (!await _ok(c)) failed.add(c);
    }
    final level = ver.isEmpty
        ? ReaderLevel.unknown
        : failed.isEmpty
            ? ReaderLevel.full
            : ReaderLevel.basic;
    return ReaderReport(version: ver.isEmpty ? '?' : ver, level: level, failed: failed);
  }

  /// Standard setup. Auto protocol: the Logan 2015 K7M ECU usually answers on
  /// CAN 500k (ISO 15765-4); older K-line ECUs are also handled.
  Future<void> init() async {
    await send('ATZ', timeout: const Duration(seconds: 5));
    for (final c in ['ATE0', 'ATL0', 'ATS1', 'ATH1', 'ATAT1', 'ATSP0']) {
      await send(c);
    }
    final r = await send('0100', timeout: const Duration(seconds: 15));
    if (isNoData(r)) {
      throw ObdException('العربية مردتش. دوّر الكونتاكت (أو شغّل الموتور) وجرب تاني.');
    }
    protocol = parseProtocolNumber(await send('ATDPN')) ?? 6;
  }

  Future<double?> readerVoltage() async => parseVoltage(await send('ATRV'));

  Future<List<EcuReply>> request(String cmd, {Duration timeout = const Duration(seconds: 5)}) async {
    final r = await send(cmd, timeout: timeout);
    if (isNoData(r)) return const [];
    return parseReply(r, protocol: protocol);
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await transport.close();
  }
}

/// Header of the engine ECU reply on CAN 11-bit.
const engineEcuCan = '7E8';

/// Human name for a module header.
String moduleNameAr(String ecu) => switch (ecu) {
      '7E8' || '10' || '18DAF110' => 'كمبيوتر الموتور',
      '7E9' || '18' || '18DAF118' => 'كمبيوتر الفتيس',
      _ => 'موديول ($ecu)',
    };

/// High-level OBD services on top of [Elm327].
class ObdService {
  ObdService(this.elm);
  final Elm327 elm;
  Set<int> supported = {};

  Future<void> loadSupportedPids() async {
    supported = {};
    for (final base in ['0100', '0120', '0140']) {
      final r = await elm.request(base);
      if (r.isEmpty) break;
      final s = decodeSupportedPids(r.first.data);
      supported.addAll(s);
      if (!s.contains(int.parse(base.substring(2), radix: 16) + 0x20)) break;
    }
  }

  Future<Map<String, List<String>>> _codes(String mode) async {
    final replies = await elm.request(mode, timeout: const Duration(seconds: 8));
    return {
      for (final r in replies) r.ecu: decodeDtcs(r.data, can: elm.isCan),
    };
  }

  Future<Map<String, List<String>>> storedCodes() => _codes('03');
  Future<Map<String, List<String>>> pendingCodes() => _codes('07');
  Future<Map<String, List<String>>> permanentCodes() => _codes('0A');

  Future<MonitorStatus?> monitorStatus() async {
    final r = await elm.request('0101');
    return r.isEmpty ? null : decodeMonitorStatus(r.first.data);
  }

  Future<double?> readPid(int pid) async {
    final def = livePids[pid];
    if (def == null) return null;
    final r = await elm.request(def.command);
    return r.isEmpty ? null : decodePid(r.first.data);
  }

  /// Freeze frame (Mode 02, frame 0): the code that saved it plus a few PIDs.
  Future<Map<String, Object>> freezeFrame() async {
    final out = <String, Object>{};
    final r = await elm.request('020200');
    if (r.isNotEmpty && r.first.data.length >= 5) {
      final d = r.first.data;
      final code = dtcFromBytes(d[3], d[4]);
      if (code != 'P0000') out['code'] = code;
    }
    if (out.isEmpty) return out;
    for (final pid in [pidCoolant, pidRpm, pidSpeed, 0x0B, 0x06, 0x07, 0x11]) {
      final def = livePids[pid]!;
      final rr = await elm.request('02${def.command.substring(2)}00');
      if (rr.isEmpty) continue;
      final d = rr.first.data;
      // 42 PID FRAME A [B]
      if (d.length >= 3 + def.bytes && d[0] == 0x42) {
        out[def.nameAr] = '${def.decode(d.sublist(3, 3 + def.bytes)).toStringAsFixed(1)} ${def.unit}';
      }
    }
    return out;
  }

  /// Mode 04. Callers MUST go through SafetyGuard first.
  Future<bool> clearCodes() async {
    final r = await elm.send('04', timeout: const Duration(seconds: 8));
    return r.contains('44');
  }
}
