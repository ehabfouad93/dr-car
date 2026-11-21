import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../obd/transport.dart';

/// A serial port as the desktop sees it. A paired Bluetooth ELM327 appears
/// as "Standard Serial over Bluetooth link (COMx)" on Windows, /dev/rfcomm0
/// on Linux, /dev/cu.OBDII-SPPDev on macOS. USB ELM327 cables work the same way.
class PortInfo {
  PortInfo(this.name, this.description, this.isBluetooth);
  final String name;
  final String description;
  final bool isBluetooth;
}

List<PortInfo> listSerialPorts() {
  final out = <PortInfo>[];
  for (final name in SerialPort.availablePorts) {
    final p = SerialPort(name);
    try {
      final desc = p.description ?? '';
      final bt = p.transport == SerialPortTransport.bluetooth ||
          RegExp(r'bluetooth|rfcomm|obd|elm|spp', caseSensitive: false).hasMatch('$name $desc');
      out.add(PortInfo(name, desc, bt));
    } finally {
      p.dispose();
    }
  }
  out.sort((a, b) => (b.isBluetooth ? 1 : 0) - (a.isBluetooth ? 1 : 0));
  return out;
}

class SerialTransport implements ObdTransport {
  SerialTransport._(this._port, this._reader, this.label);

  /// Common ELM327 speeds: 38400 (most Bluetooth clones), 9600, 115200 (vLinker, OBDLink).
  static Future<SerialTransport> open(String name, {int baud = 38400}) async {
    final port = SerialPort(name);
    if (!port.openReadWrite()) {
      final err = SerialPort.lastError;
      port.dispose();
      throw Exception('مش قادرين نفتح $name: ${err?.message ?? 'غير معروف'}');
    }
    final cfg = SerialPortConfig()
      ..baudRate = baud
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none);
    port.config = cfg;
    final reader = SerialPortReader(port, timeout: 50);
    return SerialTransport._(port, reader, '$name @ $baud');
  }

  final SerialPort _port;
  final SerialPortReader _reader;
  @override
  final String label;
  late final Stream<List<int>> _input = _reader.stream.asBroadcastStream();

  @override
  Stream<List<int>> get input => _input;

  @override
  Future<void> write(List<int> bytes) async {
    _port.write(Uint8List.fromList(bytes), timeout: 1000);
  }

  @override
  Future<void> close() async {
    _reader.close();
    _port.close();
    _port.dispose();
  }
}

/// One line of the TX/RX traffic log.
class TrafficLine {
  TrafficLine(this.time, this.tx, this.text);
  final DateTime time;
  final bool tx;
  final String text;
}

class TrafficLog extends ChangeNotifier {
  final lines = <TrafficLine>[];
  final _rx = StringBuffer();

  void tx(String s) {
    _add(TrafficLine(DateTime.now(), true, s.trim()));
  }

  void rxChunk(String s) {
    _rx.write(s);
    if (s.contains('>')) {
      final text = _rx.toString().replaceAll('>', '').replaceAll(RegExp(r'[\r\n]+'), ' | ').trim();
      _rx.clear();
      _add(TrafficLine(DateTime.now(), false, text));
    }
  }

  void _add(TrafficLine l) {
    lines.add(l);
    if (lines.length > 5000) lines.removeRange(0, 1000);
    notifyListeners();
  }

  void clear() {
    lines.clear();
    notifyListeners();
  }

  String export() => lines
      .map((l) => '${l.time.toIso8601String()} ${l.tx ? 'TX' : 'RX'} ${l.text}')
      .join('\n');
}

/// Wraps any transport and copies all traffic into a [TrafficLog].
class LoggingTransport implements ObdTransport {
  LoggingTransport(this.inner, this.log) {
    _sub = inner.input.listen((b) {
      log.rxChunk(latin1.decode(b, allowInvalid: true));
      _ctrl.add(b);
    }, onError: _ctrl.addError);
  }

  final ObdTransport inner;
  final TrafficLog log;
  final _ctrl = StreamController<List<int>>.broadcast();
  late final StreamSubscription<List<int>> _sub;

  @override
  String get label => inner.label;
  @override
  Stream<List<int>> get input => _ctrl.stream;

  @override
  Future<void> write(List<int> bytes) {
    log.tx(latin1.decode(bytes));
    return inner.write(bytes);
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    await inner.close();
    await _ctrl.close();
  }
}
