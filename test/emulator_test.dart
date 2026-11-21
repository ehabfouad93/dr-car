// End-to-end test against the real ELM327-emulator over TCP.
// Start it first:  elm -n 35000 -s car      (pip install ELM327-emulator)
// Skipped automatically when nothing listens on 127.0.0.1:35000.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logan_doctor/desktop/serial_transport.dart';
import 'package:logan_doctor/obd/elm327.dart';
import 'package:logan_doctor/obd/pids.dart';
import 'package:logan_doctor/obd/renault.dart';
import 'package:logan_doctor/obd/transport.dart';

Future<bool> _emulatorUp() async {
  try {
    (await Socket.connect('127.0.0.1', 35000, timeout: const Duration(seconds: 1))).destroy();
    return true;
  } catch (_) {
    return false;
  }
}

void main() async {
  final up = await _emulatorUp();

  test('full flow against ELM327-emulator', () async {
    final log = TrafficLog();
    final t = LoggingTransport(await TcpTransport.connect('127.0.0.1', 35000), log);
    final elm = Elm327(t);

    final rep = await elm.checkReader();
    expect(rep.version, contains('ELM327'));

    await elm.init();
    expect(elm.isCan, isTrue);

    final obd = ObdService(elm);
    await obd.loadSupportedPids();
    expect(obd.supported, containsAll([pidCoolant, pidRpm]));

    final coolant = await obd.readPid(pidCoolant);
    expect(coolant, inInclusiveRange(-40, 215));
    expect(await obd.readPid(pidRpm), greaterThan(0));
    expect(await elm.readerVoltage(), greaterThan(10));
    expect(await obd.storedCodes(), isA<Map<String, List<String>>>());

    // Renault module scan on a car without Renault modules: must fail gracefully...
    final d = RenaultDiag(elm);
    final s = await d.scan(loganModules[1]);
    expect(s.answered, isFalse);
    // ...and generic OBD must work again afterwards.
    await d.backToObd();
    expect(await obd.readPid(pidCoolant), isNotNull);

    // Forbidden services never reach the wire.
    await expectLater(elm.send('2701'), throwsA(isA<ObdException>()));
    expect(log.lines.where((l) => l.tx && l.text.contains('2701')), isEmpty);
    expect(log.lines.where((l) => l.tx).length, greaterThan(20));

    await elm.dispose();
  }, skip: up ? false : 'ELM327-emulator not running on 127.0.0.1:35000', timeout: const Timeout(Duration(minutes: 2)));
}
