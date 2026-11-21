/// Pure parsing helpers for ELM327 replies. No Flutter, no I/O, so all of it
/// is unit-tested in test/obd_parser_test.dart.
library;

/// ELM327 protocol numbers (from `AT DPN`).
/// 1-5 are the old K-line / J1850 protocols, 6-9 are CAN.
bool isCanProtocol(int p) => p >= 6 && p <= 9;
bool isCan29Bit(int p) => p == 7 || p == 9;

/// Replies from the ELM327 that mean "no answer" rather than data.
const _noDataMarkers = [
  'NO DATA',
  'UNABLE TO CONNECT',
  'CAN ERROR',
  'BUS ERROR',
  'BUS INIT: ...ERROR',
  'STOPPED',
  'ERROR',
  '?',
];

/// One module's (ECU's) reply after multi-frame reassembly.
class EcuReply {
  EcuReply(this.ecu, this.data);

  /// Header of the answering module, e.g. `7E8` (engine on CAN) or `10`.
  final String ecu;

  /// Payload starting at the service byte (e.g. 0x43 for Mode 03).
  final List<int> data;

  @override
  String toString() => 'EcuReply($ecu, ${hex(data)})';
}

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

/// Splits raw ELM text into clean data lines, dropping prompts, echoes and
/// status noise ("SEARCHING...", "BUS INIT: ...OK").
List<String> cleanLines(String raw) {
  return raw
      .replaceAll('>', '')
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .where((l) => !l.startsWith('SEARCHING'))
      .where((l) => !l.startsWith('BUS INIT'))
      .toList();
}

bool isNoData(String raw) {
  final up = raw.toUpperCase();
  return _noDataMarkers.any(up.contains) &&
      !RegExp(r'[0-9A-F]{2} [0-9A-F]{2}').hasMatch(up);
}

/// Parses a reply sent with headers on (`AT H1`) and spaces on (`AT S1`).
/// Handles CAN 11-bit, CAN 29-bit (ISO-TP multi-frame) and K-line replies.
List<EcuReply> parseReply(String raw, {required int protocol}) {
  final lines = cleanLines(raw);
  final can = isCanProtocol(protocol);
  final can29 = isCan29Bit(protocol);

  // ecu -> collected frames
  final singles = <String, List<int>>{};
  final firstLen = <String, int>{};
  final multi = <String, List<int>>{};
  final order = <String>[];

  for (final line in lines) {
    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.any((t) => !RegExp(r'^[0-9A-Fa-f]+$').hasMatch(t))) continue;

    String ecu;
    List<int> bytes;
    if (can && !can29) {
      // "7E8 06 43 02 01 15 01 30"
      if (tokens.first.length != 3) continue;
      ecu = tokens.first.toUpperCase();
      bytes = tokens.skip(1).map((t) => int.parse(t, radix: 16)).toList();
    } else if (can29) {
      // "18 DA F1 10 06 43 ..."
      if (tokens.length < 5) continue;
      ecu = tokens.take(4).join().toUpperCase();
      bytes = tokens.skip(4).map((t) => int.parse(t, radix: 16)).toList();
    } else {
      // K-line: "48 6B 10 43 01 33 00 00 00 00 CS" -> 3 header bytes + checksum
      if (tokens.length < 5) continue;
      ecu = tokens[2].toUpperCase();
      final all = tokens.map((t) => int.parse(t, radix: 16)).toList();
      bytes = all.sublist(3, all.length - 1);
      if (!order.contains(ecu)) order.add(ecu);
      // K-line multi-message replies (Mode 03) repeat the service byte on
      // every message; keep it once and append the rest.
      final existing = singles[ecu];
      if (existing == null) {
        singles[ecu] = bytes;
      } else {
        existing.addAll(bytes.skip(1));
      }
      continue;
    }

    if (!order.contains(ecu)) order.add(ecu);
    if (bytes.isEmpty) continue;
    final pci = bytes.first;
    final type = pci >> 4;
    if (type == 0) {
      final len = pci & 0x0F;
      singles[ecu] = bytes.sublist(1, (1 + len).clamp(1, bytes.length));
    } else if (type == 1 && bytes.length >= 2) {
      firstLen[ecu] = ((pci & 0x0F) << 8) | bytes[1];
      multi[ecu] = bytes.sublist(2);
    } else if (type == 2) {
      (multi[ecu] ??= []).addAll(bytes.sublist(1));
    }
  }

  return [
    for (final ecu in order)
      if (multi.containsKey(ecu))
        EcuReply(ecu, multi[ecu]!.take(firstLen[ecu] ?? multi[ecu]!.length).toList())
      else if (singles.containsKey(ecu))
        EcuReply(ecu, singles[ecu]!),
  ];
}

/// Turns two raw bytes into a code like `P0115`.
String dtcFromBytes(int a, int b) {
  const letters = ['P', 'C', 'B', 'U'];
  final letter = letters[a >> 6];
  final d1 = (a >> 4) & 0x03;
  final d2 = a & 0x0F;
  final rest = b.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '$letter$d1${d2.toRadixString(16).toUpperCase()}$rest';
}

/// Decodes a Mode 03 / 07 / 0A payload (starting with 0x43 / 0x47 / 0x4A).
/// On CAN the second byte is the code count; on K-line there is no count.
List<String> decodeDtcs(List<int> data, {required bool can}) {
  if (data.isEmpty) return const [];
  var body = data.sublist(1);
  if (can && body.isNotEmpty) {
    final count = body.first;
    body = body.sublist(1);
    if (body.length > count * 2) body = body.sublist(0, count * 2);
  }
  final out = <String>[];
  for (var i = 0; i + 1 < body.length; i += 2) {
    if (body[i] == 0 && body[i + 1] == 0) continue;
    final code = dtcFromBytes(body[i], body[i + 1]);
    if (!out.contains(code)) out.add(code);
  }
  return out;
}

/// Mode 01 PID 01: MIL (Check Engine) state and number of stored codes.
class MonitorStatus {
  MonitorStatus(this.milOn, this.dtcCount);
  final bool milOn;
  final int dtcCount;
}

MonitorStatus? decodeMonitorStatus(List<int> data) {
  // 41 01 A B C D
  if (data.length < 3 || data[0] != 0x41 || data[1] != 0x01) return null;
  return MonitorStatus((data[2] & 0x80) != 0, data[2] & 0x7F);
}

/// Decodes a "supported PIDs" bitmask reply (01 00 / 01 20 / 01 40).
Set<int> decodeSupportedPids(List<int> data) {
  if (data.length < 6) return {};
  final base = data[1];
  final out = <int>{};
  for (var i = 0; i < 32; i++) {
    final byte = data[2 + i ~/ 8];
    if (byte & (0x80 >> (i % 8)) != 0) out.add(base + i + 1);
  }
  return out;
}

/// Reads `AT RV` output like "12.6V".
double? parseVoltage(String raw) {
  final m = RegExp(r'(\d{1,2}\.\d)\s*V', caseSensitive: false).firstMatch(raw);
  return m == null ? null : double.parse(m.group(1)!);
}

/// Reads protocol number from `AT DPN` output: "A6" (auto, 6) or "6".
int? parseProtocolNumber(String raw) {
  final l = cleanLines(raw);
  if (l.isEmpty) return null;
  final s = l.first.toUpperCase().replaceFirst('A', '');
  return int.tryParse(s, radix: 16);
}
