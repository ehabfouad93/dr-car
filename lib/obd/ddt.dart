/// Reader for ECU definition files in the DDT4ALL JSON layout
/// (keys: ecuname, obd{send_id,recv_id}, endian, data{}, requests[]).
///
/// The definitions themselves are NOT shipped with the app: they derive from
/// Renault's DDT2000 database. The owner imports the file for their own ECU.
/// This file is our own implementation of the format, not DDT4ALL code.
library;

import 'dart:convert';
import 'dart:math' as math;

class DdtData {
  DdtData(this.name, Map<String, dynamic> j)
      : bits = (j['bitscount'] as num?)?.toInt() ?? 8,
        bytes = (j['bytescount'] as num?)?.toInt() ?? 1,
        scaled = j['scaled'] == true,
        signed = j['signed'] == true,
        ascii = j['bytesascii'] == true,
        step = (j['step'] as num?)?.toDouble() ?? 1,
        offset = (j['offset'] as num?)?.toDouble() ?? 0,
        divideBy = (j['divideby'] as num?)?.toDouble() ?? 1,
        format = j['format'] as String? ?? '',
        unit = j['unit'] as String? ?? '',
        comment = j['comment'] as String? ?? '',
        lists = {
          for (final e in ((j['lists'] as Map?) ?? {}).entries) int.parse(e.key.toString()): e.value.toString(),
        };

  final String name;
  final int bits;
  final int bytes;
  final bool scaled;
  final bool signed;
  final bool ascii;
  final double step;
  final double offset;
  final double divideBy;
  final String format;
  final String unit;
  final String comment;
  final Map<int, String> lists;
}

class DdtItem {
  DdtItem(this.name, Map<String, dynamic> j)
      : firstByte = (j['firstbyte'] as num?)?.toInt() ?? 0,
        bitOffset = (j['bitoffset'] as num?)?.toInt() ?? 0,
        endian = j['endian'] as String? ?? '';
  final String name;
  final int firstByte; // 1-based
  final int bitOffset;
  final String endian;
}

enum DdtKind { read, control, dtc, blocked, other }

class DdtRequest {
  DdtRequest(Map<String, dynamic> j)
      : name = j['name'] as String,
        sent = (j['sentbytes'] as String? ?? '').toUpperCase(),
        replyPrefix = (j['replybytes'] as String? ?? '').toUpperCase(),
        sendItems = _items(j['sendbyte_dataitems']),
        recvItems = _items(j['receivebyte_dataitems']);

  static List<DdtItem> _items(Object? m) =>
      ((m as Map?) ?? {}).entries.map((e) => DdtItem(e.key as String, (e.value as Map).cast<String, dynamic>())).toList();

  final String name;
  final String sent;
  final String replyPrefix;
  final List<DdtItem> sendItems;
  final List<DdtItem> recvItems;

  String get service => sent.length >= 2 ? sent.substring(0, 2) : '';

  DdtKind get kind => switch (service) {
        '21' || '22' || '1A' => DdtKind.read,
        '17' || '18' || '19' => DdtKind.dtc,
        '30' || '2F' => DdtKind.control, // InputOutputControl (actuator tests)
        // Writes, routines, security, flashing, comm control: never from this app.
        '2E' || '3B' || '31' || '27' || '34' || '35' || '36' || '37' || '3D' || '28' || '85' || '11' || '14' || '10' => DdtKind.blocked,
        _ => DdtKind.other,
      };
}

class DdtEcu {
  DdtEcu.fromJson(String src) {
    final j = jsonDecode(src) as Map<String, dynamic>;
    name = j['ecuname'] as String? ?? '?';
    final obd = (j['obd'] as Map?)?.cast<String, dynamic>() ?? {};
    sendId = (obd['send_id'] as String? ?? '').toUpperCase();
    recvId = (obd['recv_id'] as String? ?? '').toUpperCase();
    littleEndian = j['endian'] == 'Little';
    data = {
      for (final e in ((j['data'] as Map?) ?? {}).entries)
        e.key as String: DdtData(e.key as String, (e.value as Map).cast<String, dynamic>()),
    };
    requests = ((j['requests'] as List?) ?? []).map((r) => DdtRequest((r as Map).cast<String, dynamic>())).toList();
  }

  late final String name;
  late final String sendId;
  late final String recvId;
  late final bool littleEndian;
  late final Map<String, DdtData> data;
  late final List<DdtRequest> requests;

  Iterable<DdtRequest> get readRequests => requests.where((r) => r.kind == DdtKind.read && r.recvItems.isNotEmpty);
  Iterable<DdtRequest> get controlRequests => requests.where((r) => r.kind == DdtKind.control);

  bool _little(DdtItem i) => i.endian == 'Little' || (i.endian != 'Big' && littleEndian);

  /// Raw integer of one item inside a reply (bit-exact, both endiannesses).
  int? rawValue(List<int> reply, DdtItem item) {
    final d = data[item.name];
    if (d == null) return null;
    final start = item.firstByte - 1;
    final nBytes = ((d.bits + item.bitOffset) / 8).ceil();
    if (start < 0 || start + nBytes > reply.length) return null;
    final slice = reply.sublist(start, start + nBytes);
    final mask = d.bits >= 63 ? -1 : (1 << d.bits) - 1;
    if (_little(item)) {
      var v = 0;
      for (final b in slice.reversed) {
        v = (v << 8) | b;
      }
      return (v >> item.bitOffset) & mask;
    }
    // Big endian: bit offset counts from the MSB of the first byte.
    var v = 0;
    for (final b in slice) {
      v = (v << 8) | b;
    }
    final shift = nBytes * 8 - item.bitOffset - d.bits;
    return (v >> shift) & mask;
  }

  /// Human value: list label, scaled number with unit, ASCII, or hex.
  String? display(List<int> reply, DdtItem item) {
    final d = data[item.name];
    if (d == null) return null;
    if (d.ascii) {
      final s = item.firstByte - 1;
      if (s < 0 || s + d.bytes > reply.length) return null;
      return String.fromCharCodes(reply.sublist(s, s + d.bytes)).trim();
    }
    var v = rawValue(reply, item);
    if (v == null) return null;
    if (d.signed && d.bits < 63 && (v & (1 << (d.bits - 1))) != 0) v -= 1 << d.bits;
    if (d.lists.containsKey(v)) return d.lists[v];
    if (!d.scaled) return '0x${v.toRadixString(16).toUpperCase()}';
    if (d.divideBy == 0) return null;
    final res = (v * d.step + d.offset) / d.divideBy;
    final decimals = d.format.contains('.') ? d.format.split('.')[1].length : (res == res.roundToDouble() ? 0 : 2);
    return '${res.toStringAsFixed(decimals)}${d.unit.isEmpty ? '' : ' ${d.unit}'}';
  }

  /// Builds the bytes for a request, inserting user-chosen values
  /// (raw integers, already range-checked by the UI) into the send template.
  List<int> buildSend(DdtRequest r, Map<String, int> rawValues) {
    final bytes = <int>[for (var i = 0; i + 1 < r.sent.length; i += 2) int.parse(r.sent.substring(i, i + 2), radix: 16)];
    for (final item in r.sendItems) {
      final v = rawValues[item.name];
      final d = data[item.name];
      if (v == null || d == null) continue;
      final start = item.firstByte - 1;
      final nBytes = ((d.bits + item.bitOffset) / 8).ceil();
      while (bytes.length < start + nBytes) {
        bytes.add(0);
      }
      final mask = (1 << d.bits) - 1;
      if (_little(item)) {
        var cur = 0;
        for (var i = nBytes - 1; i >= 0; i--) {
          cur = (cur << 8) | bytes[start + i];
        }
        cur = (cur & ~(mask << item.bitOffset)) | ((v & mask) << item.bitOffset);
        for (var i = 0; i < nBytes; i++) {
          bytes[start + i] = (cur >> (8 * i)) & 0xFF;
        }
      } else {
        var cur = 0;
        for (var i = 0; i < nBytes; i++) {
          cur = (cur << 8) | bytes[start + i];
        }
        final shift = nBytes * 8 - item.bitOffset - d.bits;
        cur = (cur & ~(mask << shift)) | ((v & mask) << shift);
        for (var i = nBytes - 1; i >= 0; i--) {
          bytes[start + i] = cur & 0xFF;
          cur >>= 8;
        }
      }
    }
    return bytes;
  }

  /// Raw value for a scaled user input: raw = (value * divideBy - offset) / step.
  int toRaw(DdtData d, double value) => ((value * d.divideBy - d.offset) / d.step).round().clamp(0, math.pow(2, d.bits).toInt() - 1);

  /// "Give control back to the ECU" for an actuator request:
  /// KWP `30 id 00`, UDS `2F idHi idLo 00`.
  static String stopCommandFor(DdtRequest r) {
    if (r.service == '30' && r.sent.length >= 4) return '30${r.sent.substring(2, 4)}00';
    if (r.service == '2F' && r.sent.length >= 6) return '2F${r.sent.substring(2, 6)}00';
    return '';
  }
}
