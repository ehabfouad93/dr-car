import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logan_doctor/data/dtc_repo.dart';
import 'package:logan_doctor/obd/ddt.dart';
import 'package:logan_doctor/obd/elm327.dart';
import 'package:logan_doctor/obd/obd_parser.dart';
import 'package:logan_doctor/obd/pids.dart';
import 'package:logan_doctor/obd/renault.dart';
import 'package:logan_doctor/obd/transport.dart';
import 'package:logan_doctor/services/alerts.dart';
import 'package:logan_doctor/services/safety.dart';

void main() {
  group('parser', () {
    test('CAN single frame Mode 03 with two codes', () {
      final r = parseReply('7E8 06 43 02 01 15 01 30 \r\r>', protocol: 6);
      expect(r.single.ecu, '7E8');
      expect(decodeDtcs(r.single.data, can: true), ['P0115', 'P0130']);
    });

    test('CAN multi-frame Mode 03 (4 codes)', () {
      const raw = '7E8 10 0A 43 04 01 15 03 00\r7E8 21 03 35 05 05 00 00\r>';
      final r = parseReply(raw, protocol: 6);
      expect(decodeDtcs(r.single.data, can: true), ['P0115', 'P0300', 'P0335', 'P0505']);
    });

    test('K-line Mode 03', () {
      final r = parseReply('48 6B 10 43 01 15 04 80 00 00 C3\r>', protocol: 5);
      expect(decodeDtcs(r.single.data, can: false), ['P0115', 'P0480']);
    });

    test('no data', () {
      expect(isNoData('NO DATA\r\r>'), isTrue);
      expect(isNoData('7E8 03 41 05 7B\r>'), isFalse);
    });

    test('PID decode coolant and rpm', () {
      expect(decodePid([0x41, 0x05, 0x7B]), 83);
      expect(decodePid([0x41, 0x0C, 0x0B, 0xB8]), 750);
    });

    test('MIL status + voltage + protocol', () {
      expect(decodeMonitorStatus([0x41, 0x01, 0x82, 0, 0, 0])!.milOn, isTrue);
      expect(decodeMonitorStatus([0x41, 0x01, 0x82, 0, 0, 0])!.dtcCount, 2);
      expect(parseVoltage('14.1V\r>'), 14.1);
      expect(parseProtocolNumber('A6\r>'), 6);
    });
  });

  test('fault guide: every code has Arabic text and severity', () {
    final repo = DtcRepo(File('assets/logan_dtc.json').readAsStringSync());
    expect(repo.size, greaterThan(60));
    expect(repo.lookup('P0335').severity, Severity.stop);
    expect(repo.lookup('P0302').nameAr, contains('2'));
    final unknown = repo.lookup('P1234');
    expect(unknown.inGuide, isFalse);
    expect(unknown.nameAr, isNotEmpty);
  });

  group('safety', () {
    final g = SafetyGuard();
    test('no writes while moving or speed unknown', () {
      expect(g.canWrite(speedKmh: 20).allowed, isFalse);
      expect(g.canWrite(speedKmh: null).allowed, isFalse);
      expect(g.canWrite(speedKmh: 0).allowed, isTrue);
    });
    test('flashing / security / config writes blocked', () {
      for (final c in ['2701', '3401', '3B8001', '2EF190', '3101FF']) {
        expect(g.isForbiddenCommand(c), isTrue, reason: c);
      }
      // Same services hidden behind an ISO-TP length byte (raw CAN mode).
      for (final c in ['022701', '0234', '03 3B 80 01', '1008 2E F1 90']) {
        expect(g.isForbiddenCommand(c, rawFrame: true), isTrue, reason: c);
      }
      for (final c in ['0210C0', '022180', '0317FF00', '04300500']) {
        expect(g.isForbiddenCommand(c, rawFrame: true), isFalse, reason: c);
      }
      // Normal OBD readings that only look like raw frames stay allowed.
      for (final c in ['ATZ', '0105', '03', '04', '300101', '0131', '0137', '023400']) {
        expect(g.isForbiddenCommand(c), isFalse, reason: c);
      }
    });
  });

  group('alerts', () {
    test('overheat fires once and re-arms', () {
      final e = AlertEngine();
      expect(e.feed(Reading(coolantC: 106)).single.id, AlertEngine.idHot);
      expect(e.feed(Reading(coolantC: 108)), isEmpty);
      e.feed(Reading(coolantC: 95));
      expect(e.feed(Reading(coolantC: 107)), hasLength(1));
    });
    test('charging needs 3 low readings with engine running', () {
      final e = AlertEngine();
      expect(e.feed(Reading(volts: 12.5, rpm: 800)), isEmpty);
      expect(e.feed(Reading(volts: 12.5, rpm: 800)), isEmpty);
      expect(e.feed(Reading(volts: 12.5, rpm: 800)).single.id, AlertEngine.idCharge);
      expect(AlertEngine().feed(Reading(volts: 12.0, rpm: 0)), isEmpty);
    });
    test('new code and MIL on', () {
      final e = AlertEngine();
      e.feed(Reading(codes: {'P0115'}, milOn: false));
      final out = e.feed(Reading(codes: {'P0115', 'P0480'}, milOn: true));
      expect(out.map((a) => a.id), containsAll([AlertEngine.idNewCode, AlertEngine.idMil]));
    });
  });

  group('ELM327 driver against a fake car', () {
    test('reader check, init, scan, clear', () async {
      final t = FakeTransport({
        'ATI': 'ELM327 v1.5',
        'ATDPN': 'A6',
        'ATRV': '12.6V',
        '0100': '7E8 06 41 00 BE 1F B8 10',
        '0101': '7E8 06 41 01 82 07 65 00',
        '03': '7E8 06 43 02 01 15 04 80',
        '07': 'NO DATA',
        '0A': 'NO DATA',
        '010D': '7E8 03 41 0D 00',
        '04': '7E8 01 44',
      });
      final elm = Elm327(t);
      final rep = await elm.checkReader();
      expect(rep.level, ReaderLevel.full);
      await elm.init();
      expect(elm.protocol, 6);
      final obd = ObdService(elm);
      expect((await obd.storedCodes())['7E8'], ['P0115', 'P0480']);
      expect((await obd.monitorStatus())!.milOn, isTrue);
      expect(await obd.readPid(pidSpeed), 0);
      expect(await obd.clearCodes(), isTrue);
    });

    test('clone missing commands is reported as basic', () async {
      final t = FakeTransport({'ATI': 'ELM327 v2.1', 'ATFCSM0': '?', 'ATPPS': '?'});
      final rep = await Elm327(t).checkReader();
      expect(rep.level, ReaderLevel.basic);
      expect(rep.failed, containsAll(['ATFCSM0', 'ATPPS']));
    });

    test('forbidden command never reaches the reader', () async {
      final t = FakeTransport({});
      await expectLater(Elm327(t).send('2701'), throwsA(isA<ObdException>()));
      expect(t.sent, isEmpty);
    });
  });

  group('Renault multi-module', () {
    test('scan engine module: session, ident, KWP DTCs', () async {
      final t = FakeTransport({
        '0210C0': '7E8 02 50 C0',
        '022180': '7E8 10 08 61 80 41 42 43\r7E8 21 44 45 46',
        '0317FF00': '7E8 10 08 57 02 00 01 A0 00\r7E8 21 18 20',
      });
      final elm = Elm327(t);
      final s = await RenaultDiag(elm).scan(loganModules.first);
      expect(s.answered, isTrue);
      expect(s.dtcs.map((d) => d.label), ['DF001', 'DF018']);
      expect(s.dtcs.first.present, isTrue);
      expect(t.sent, contains('ATCRA7E8'));
    });

    test('forbidden service blocked even through raw()', () async {
      final t = FakeTransport({});
      await expectLater(RenaultDiag(Elm327(t)).raw('2701'), throwsA(isA<ObdException>()));
      expect(t.sent.where((c) => c.contains('2701')), isEmpty);
    });

    test('silent module', () async {
      final s = await RenaultDiag(Elm327(FakeTransport({}))).scan(loganModules[1]);
      expect(s.answered, isFalse);
    });
  });

  group('DDT definition interpreter', () {
    final ecu = DdtEcu.fromJson(jsonEncode({
      'ecuname': 'TEST_EMS',
      'obd': {'send_id': '7E0', 'recv_id': '7E8'},
      'endian': 'Big',
      'data': {
        'Coolant': {'bitscount': 8, 'scaled': true, 'step': 1, 'offset': -40, 'unit': '°C'},
        'Battery': {'bitscount': 16, 'scaled': true, 'step': 0.01, 'format': '#.##', 'unit': 'V'},
        'FanState': {'bitscount': 1, 'lists': {'0': 'OFF', '1': 'ON'}},
        'FanCmd': {'bitscount': 8, 'lists': {'0': 'Stop', '1': 'Low speed', '2': 'High speed'}},
      },
      'requests': [
        {
          'name': 'Read engine block',
          'sentbytes': '2101',
          'receivebyte_dataitems': {
            'Coolant': {'firstbyte': 3},
            'Battery': {'firstbyte': 4},
            'FanState': {'firstbyte': 6, 'bitoffset': 7},
          },
        },
        {
          'name': 'Cooling fan test',
          'sentbytes': '30050000',
          'sendbyte_dataitems': {'FanCmd': {'firstbyte': 4}},
        },
        {'name': 'Write VIN', 'sentbytes': '3B81'},
      ],
    }));

    test('classifies requests', () {
      expect(ecu.readRequests.single.name, 'Read engine block');
      expect(ecu.controlRequests.single.name, 'Cooling fan test');
      expect(ecu.requests.last.kind, DdtKind.blocked);
    });

    test('decodes scaled, list and bit values', () {
      final reply = [0x61, 0x01, 0x7B, 0x05, 0x6E, 0x01];
      final r = ecu.readRequests.single;
      String v(String n) => ecu.display(reply, r.recvItems.firstWhere((i) => i.name == n))!;
      expect(v('Coolant'), '83 °C');
      expect(v('Battery'), '13.90 V');
      expect(v('FanState'), 'ON');
    });

    test('builds actuator command and stop command', () {
      final r = ecu.controlRequests.single;
      expect(hex(ecu.buildSend(r, {'FanCmd': 2})), '30 05 00 02');
      expect(DdtEcu.stopCommandFor(r), '300500');
    });
  });
}
