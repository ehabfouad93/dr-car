import 'dart:async';

import 'package:flutter/services.dart';

import 'transport.dart';

/// Talks to the native Android Bluetooth code in ObdBluetooth.kt.
class NativeBt {
  static const _m = MethodChannel('logan/bt');
  static const _e = EventChannel('logan/bt/data');

  static Future<List<BtDevice>> bonded() async =>
      ((await _m.invokeListMethod<Map>('bonded')) ?? []).map(BtDevice.fromMap).toList();

  static Future<List<BtDevice>> scanBle({int ms = 6000}) async =>
      ((await _m.invokeListMethod<Map>('scanBle', {'ms': ms})) ?? []).map(BtDevice.fromMap).toList();

  static Future<void> notify(int id, String title, String body) =>
      _m.invokeMethod('notify', {'id': id, 'title': title, 'body': body});

  static Future<void> startMonitorService() => _m.invokeMethod('startService');
  static Future<void> stopMonitorService() => _m.invokeMethod('stopService');
}

class BtDevice {
  BtDevice(this.name, this.address, this.ble);
  factory BtDevice.fromMap(Map m) =>
      BtDevice(m['name'] as String, m['address'] as String, m['type'] == 'ble');
  final String name;
  final String address;
  final bool ble;

  /// Most ELM327 readers advertise as "OBDII", "OBD2", "V-LINK", "Vgate"...
  bool get looksLikeObd =>
      RegExp(r'obd|elm|v-?link|vgate|icar|konnwei|viecar|veepeak', caseSensitive: false).hasMatch(name);
}

class BluetoothTransport implements ObdTransport {
  BluetoothTransport._(this.device);

  static Future<BluetoothTransport> connect(BtDevice d) async {
    final t = BluetoothTransport._(d);
    t._sub = NativeBt._e.receiveBroadcastStream().listen(
          (e) => t._ctrl.add(e as Uint8List),
          onError: (Object e) => t._ctrl.addError(e),
        );
    await NativeBt._m.invokeMethod(d.ble ? 'connectBle' : 'connectClassic', {'address': d.address});
    return t;
  }

  final BtDevice device;
  final _ctrl = StreamController<List<int>>.broadcast();
  StreamSubscription<dynamic>? _sub;

  @override
  String get label => '${device.name} (${device.ble ? 'BLE' : 'Bluetooth'})';

  @override
  Stream<List<int>> get input => _ctrl.stream;

  @override
  Future<void> write(List<int> bytes) =>
      NativeBt._m.invokeMethod('write', {'data': Uint8List.fromList(bytes)});

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await NativeBt._m.invokeMethod('close');
    await _ctrl.close();
  }
}
