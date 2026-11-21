import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A byte pipe to an ELM327 reader. Implementations: classic Bluetooth
/// (most cheap readers in Egypt), BLE, and TCP (Wi-Fi readers and the
/// laptop ELM327-emulator used for testing without a car).
abstract class ObdTransport {
  String get label;
  Stream<List<int>> get input;
  Future<void> write(List<int> bytes);
  Future<void> close();
}

/// TCP transport: Wi-Fi ELM327 readers (usually 192.168.0.10:35000) and the
/// Python `ELM327-emulator` (`elm -n 35000`). Also used in tests.
class TcpTransport implements ObdTransport {
  TcpTransport._(this._socket, this.label);

  static Future<TcpTransport> connect(String host, int port) async {
    final s = await Socket.connect(host, port, timeout: const Duration(seconds: 8));
    s.setOption(SocketOption.tcpNoDelay, true);
    return TcpTransport._(s, 'Wi-Fi $host:$port');
  }

  final Socket _socket;
  @override
  final String label;
  late final Stream<List<int>> _input = _socket.asBroadcastStream();

  @override
  Stream<List<int>> get input => _input;

  @override
  Future<void> write(List<int> bytes) async {
    _socket.add(bytes);
    await _socket.flush();
  }

  @override
  Future<void> close() => _socket.close();
}

/// In-memory fake used by unit tests: answers commands from a script map.
class FakeTransport implements ObdTransport {
  FakeTransport(this.answers);

  /// command (no spaces, upper) -> reply text (without trailing prompt).
  final Map<String, String> answers;
  final _ctrl = StreamController<List<int>>.broadcast();
  final sent = <String>[];

  @override
  String get label => 'fake';
  @override
  Stream<List<int>> get input => _ctrl.stream;

  @override
  Future<void> write(List<int> bytes) async {
    final cmd = ascii.decode(bytes).trim().replaceAll(' ', '').toUpperCase();
    sent.add(cmd);
    final reply = answers[cmd] ?? (cmd.startsWith('AT') ? 'OK' : 'NO DATA');
    scheduleMicrotask(() => _ctrl.add(ascii.encode('$reply\r\r>')));
  }

  @override
  Future<void> close() => _ctrl.close();
}
