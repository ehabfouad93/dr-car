/// Alert rules from the plan, as pure logic (tested in test/alerts_test.dart).
/// The monitor loop feeds readings in; the engine says which alerts to fire.
library;

class AlertThresholds {
  const AlertThresholds({this.coolantMaxC = 105, this.chargingMinV = 13.2, this.runningRpm = 500});
  final double coolantMaxC;
  final double chargingMinV;
  final double runningRpm;
}

class Alert {
  Alert(this.id, this.titleAr, this.bodyAr);
  final int id;
  final String titleAr;
  final String bodyAr;
}

class Reading {
  Reading({this.coolantC, this.volts, this.rpm, this.speed, this.milOn, this.codes});
  final double? coolantC;
  final double? volts;
  final double? rpm;
  final double? speed;
  final bool? milOn;
  final Set<String>? codes;
}

class AlertEngine {
  AlertEngine({this.t = const AlertThresholds(), DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AlertThresholds t;
  final DateTime Function() _now;

  // Each alert fires once, then re-arms only after the condition clears.
  final _active = <int>{};
  int _lowVoltCount = 0;
  Set<String>? _knownCodes;
  bool? _lastMil;
  DateTime? _engineOffSince;

  static const idHot = 1, idCharge = 2, idNewCode = 3, idMil = 4, idDrain = 5;

  List<Alert> feed(Reading r) {
    final out = <Alert>[];

    void edge(int id, bool cond, Alert Function() make) {
      if (cond && !_active.contains(id)) {
        _active.add(id);
        out.add(make());
      } else if (!cond) {
        _active.remove(id);
      }
    }

    if (r.coolantC != null) {
      edge(idHot, r.coolantC! > t.coolantMaxC, () => Alert(idHot, '🔥 الموتور سخن: ${r.coolantC!.round()}°م',
          'اطفي التكييف، وقف على جنب بأمان وسيب الموتور في الرالنتي لحد ما الحرارة تنزل. ماتفتحش غطا الرادياتير وهو سخن.'));
    }

    // Need 3 low readings in a row with the engine running, to skip cranking dips.
    if (r.volts != null && r.rpm != null) {
      final low = r.rpm! > t.runningRpm && r.volts! < t.chargingMinV;
      _lowVoltCount = low ? _lowVoltCount + 1 : 0;
      edge(idCharge, _lowVoltCount >= 3, () => Alert(idCharge, '🔋 الشحن ضعيف: ${r.volts!.toStringAsFixed(1)} فولت',
          'الدينامو غالبًا مش بيشحن كويس. افحص سير الدينامو وأقطاب البطارية قبل ما العربية تقف منك.'));
    }

    if (r.codes != null) {
      final known = _knownCodes;
      if (known != null) {
        final fresh = r.codes!.difference(known);
        if (fresh.isNotEmpty) {
          out.add(Alert(idNewCode, '⚠️ عطل جديد: ${fresh.join('، ')}', 'افتح التطبيق عشان تشوف العطل ده معناه إيه ومدى خطورته.'));
        }
      }
      _knownCodes = {...?known, ...r.codes!};
    }

    if (r.milOn != null) {
      if (r.milOn! && _lastMil == false) {
        out.add(Alert(idMil, '🟠 لمبة المحرك نورت', 'كمبيوتر الموتور سجّل عطل. افتح التطبيق واعمل سكان.'));
      }
      _lastMil = r.milOn;
    }

    // Reader left plugged in with the engine off drains the battery.
    if (r.rpm != null) {
      if (r.rpm! < 1) {
        _engineOffSince ??= _now();
        edge(idDrain, _now().difference(_engineOffSince!) > const Duration(minutes: 10), () => Alert(idDrain,
            '🔌 القارئ لسه متوصل والموتور مطفي', 'شيل قارئ OBD من الفيشة عشان مايفضيش البطارية.'));
      } else {
        _engineOffSince = null;
        _active.remove(idDrain);
      }
    }

    return out;
  }
}
