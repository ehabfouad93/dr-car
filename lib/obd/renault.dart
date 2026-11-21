/// Renault-specific diagnostics for the Logan II (DDT4ALL project "X52"):
/// talks to every module on the CAN bus, not just the engine's OBD side.
///
/// Addresses come from DDT4ALL projects.json + pyren (both agree):
/// Logan II = CAN 500 kbps, 11-bit, OBD pins 6/14 only, no K-line.
library;

import '../services/safety.dart';
import 'elm327.dart';
import 'obd_parser.dart';

class RenaultModule {
  const RenaultModule(this.diagAddr, this.nameAr, this.tx, this.rx, {this.likelyFitted = true});
  final String diagAddr; // Renault diag address, e.g. 7A
  final String nameAr;
  final String tx; // request CAN ID
  final String rx; // response CAN ID
  final bool likelyFitted;
}

/// Logan II / X52 module map. Whether each one is fitted varies by trim:
/// the scan finds out on the real car.
const loganModules = [
  RenaultModule('7A', 'كمبيوتر الموتور', '7E0', '7E8'),
  RenaultModule('01', 'الفرامل ABS', '740', '760'),
  RenaultModule('2C', 'الإيرباج', '752', '772'),
  RenaultModule('26', 'كمبيوتر الكابينة UCH (المفتاح والإضاءة والسنتر لوك)', '745', '765'),
  RenaultModule('51', 'العداد', '743', '763'),
  RenaultModule('04', 'الدركسيون الكهربا', '742', '762', likelyFitted: false),
  RenaultModule('29', 'التكييف الأوتوماتيك', '744', '764', likelyFitted: false),
  RenaultModule('27', 'علبة الفيوزات UPC', '74D', '76D', likelyFitted: false),
  RenaultModule('13', 'الراديو', '712', '732', likelyFitted: false),
  RenaultModule('58', 'شاشة Media-Nav', '747', '767', likelyFitted: false),
  RenaultModule('2F', 'الريموت', '74C', '76C', likelyFitted: false),
];

class ModuleScan {
  ModuleScan(this.module, {this.answered = false, this.identHex = '', this.dtcs = const [], this.uds = false});
  final RenaultModule module;
  final bool answered;
  final String identHex;
  final List<RawDtc> dtcs;
  final bool uds;
}

/// A fault as the module reports it. On Renault KWP modules [code] is the
/// DF number; on UDS modules it is the 3-byte DTC.
class RawDtc {
  RawDtc(this.code, this.status);
  final int code;
  final int status;

  String get label => code > 0xFFFF
      ? dtcFromBytes(code >> 16, (code >> 8) & 0xFF) + (code & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()
      : 'DF${code.toRadixString(16).padLeft(3, '0').toUpperCase()}';

  /// KWP status bit 0x80 / UDS bit 0x01 (testFailed) = present now.
  bool get present => (status & 0x81) != 0;
}

/// Renault diag session on top of the ELM327, the same way DDT4ALL / pyren do it:
/// raw CAN frames (CAF0), explicit flow control, session 10C0, ident 2180.
class RenaultDiag {
  RenaultDiag(this.elm);
  final Elm327 elm;
  RenaultModule? current;

  /// [protocol] 6 = CAN 500 kbps 11-bit (Logan II), 8 = CAN 250 kbps 11-bit.
  Future<void> select(RenaultModule m, {int protocol = 6}) async {
    for (final c in [
      'ATSP$protocol', 'ATH1', 'ATCAF0', 'ATSH${m.tx}', 'ATFCSH${m.tx}', 'ATFCSD300000', 'ATFCSM1', 'ATCRA${m.rx}',
    ]) {
      await elm.send(c);
    }
    current = m;
  }

  /// Back to normal OBD so the generic engine screens keep working.
  Future<void> backToObd() async {
    for (final c in ['ATCRA', 'ATFCSM0', 'ATCAF1', 'ATSH7DF', 'ATSP0']) {
      await elm.send(c);
    }
    await elm.send('0100', timeout: const Duration(seconds: 10));
    current = null;
  }

  /// Sends a service payload (hex, no PCI). CAF0 means we add the ISO-TP
  /// single-frame length byte ourselves. Returns the reassembled reply payload.
  Future<List<int>?> raw(String payloadHex, {Duration timeout = const Duration(seconds: 3)}) async {
    final p = payloadHex.replaceAll(' ', '').toUpperCase();
    if (SafetyGuard().isForbiddenCommand(p)) {
      throw ObdException('الأمر ده ممنوع في التطبيق لأنه بيبرمج أو بيفتح حماية الكمبيوتر.');
    }
    final len = p.length ~/ 2;
    if (len == 0 || len > 7) throw ObdException('الطلب طويل على القارئ ده ($len بايت).');
    final r = await elm.send('${len.toRadixString(16).padLeft(2, '0').toUpperCase()}$p', timeout: timeout);
    if (isNoData(r)) return null;
    final replies = parseReply(r, protocol: 6);
    final mine = replies.where((e) => e.ecu == current?.rx).toList();
    if (mine.isEmpty) return null;
    // A '7F xx 78' (response pending) is returned as-is: we never resend
    // automatically, so a control command can't be sent twice by mistake.
    final data = mine.last.data;
    return data;
  }

  static bool positive(List<int>? d, int service) => d != null && d.isNotEmpty && d[0] == service + 0x40;

  Future<ModuleScan> scan(RenaultModule m, {int protocol = 6}) async {
    await select(m, protocol: protocol);
    var session = await raw('10C0');
    var uds = false;
    if (!positive(session, 0x10)) {
      session = await raw('1003'); // newer UDS-style modules
      uds = positive(session, 0x10);
      if (!uds) return ModuleScan(m);
    }
    final ident = uds ? await raw('22F18A') : await raw('2180');
    final identHex = ident == null ? '' : hex(ident);

    var dtcs = <RawDtc>[];
    final kwp = uds ? null : await raw('17FF00', timeout: const Duration(seconds: 5));
    if (positive(kwp, 0x17) && kwp!.length >= 2) {
      // 57 N [hi lo status]...
      final body = kwp.sublist(2);
      for (var i = 0; i + 2 < body.length; i += 3) {
        dtcs.add(RawDtc((body[i] << 8) | body[i + 1], body[i + 2]));
      }
    } else {
      final u = await raw('1902AF', timeout: const Duration(seconds: 5));
      if (positive(u, 0x19) && u!.length >= 3) {
        uds = true;
        final body = u.sublist(3); // 59 02 mask [d1 d2 d3 status]...
        for (var i = 0; i + 3 < body.length; i += 4) {
          dtcs.add(RawDtc((body[i] << 16) | (body[i + 1] << 8) | body[i + 2], body[i + 3]));
        }
      }
    }
    return ModuleScan(m, answered: true, identHex: identHex, dtcs: dtcs, uds: uds);
  }

  /// Clears one module's fault memory. Caller must pass SafetyGuard first.
  Future<bool> clear(RenaultModule m, {required bool uds}) async {
    await select(m);
    await raw(uds ? '1003' : '10C0');
    final r = await raw(uds ? '14FFFFFF' : '14FF00', timeout: const Duration(seconds: 6));
    return positive(r, 0x14);
  }
}
