/// Mode 01 live-data PIDs used for the Logan 2015 K7M dashboard.
library;

class PidDef {
  const PidDef({
    required this.pid,
    required this.nameAr,
    required this.unit,
    required this.bytes,
    required this.decode,
    this.min = 0,
    this.max = 100,
  });

  final int pid;
  final String nameAr;
  final String unit;
  final int bytes;
  final double Function(List<int> b) decode;
  final double min;
  final double max;

  String get command => '01${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

double _trim(List<int> b) => (b[0] - 128) * 100 / 128;

const pidCoolant = 0x05;
const pidRpm = 0x0C;
const pidSpeed = 0x0D;
const pidControlVoltage = 0x42;

final Map<int, PidDef> livePids = {
  for (final p in [
    PidDef(pid: pidCoolant, nameAr: 'حرارة المياه', unit: '°C', bytes: 1, decode: (b) => b[0] - 40.0, min: -40, max: 130),
    PidDef(pid: pidRpm, nameAr: 'لفات الموتور', unit: 'rpm', bytes: 2, decode: (b) => (b[0] * 256 + b[1]) / 4, max: 7000),
    PidDef(pid: pidSpeed, nameAr: 'السرعة', unit: 'كم/س', bytes: 1, decode: (b) => b[0].toDouble(), max: 200),
    PidDef(pid: 0x11, nameAr: 'فتحة البوابة (التيتل)', unit: '%', bytes: 1, decode: (b) => b[0] * 100 / 255),
    PidDef(pid: 0x0F, nameAr: 'حرارة الهوا الداخل', unit: '°C', bytes: 1, decode: (b) => b[0] - 40.0, min: -40, max: 100),
    PidDef(pid: 0x0B, nameAr: 'ضغط المانيفولد (MAP)', unit: 'kPa', bytes: 1, decode: (b) => b[0].toDouble(), max: 110),
    PidDef(pid: 0x06, nameAr: 'تصحيح البنزين القصير', unit: '%', bytes: 1, decode: _trim, min: -30, max: 30),
    PidDef(pid: 0x07, nameAr: 'تصحيح البنزين الطويل', unit: '%', bytes: 1, decode: _trim, min: -30, max: 30),
    PidDef(pid: 0x14, nameAr: 'حساس الأكسجين الأمامي', unit: 'V', bytes: 2, decode: (b) => b[0] / 200, max: 1.1),
    PidDef(pid: 0x15, nameAr: 'حساس الأكسجين الخلفي', unit: 'V', bytes: 2, decode: (b) => b[0] / 200, max: 1.1),
    PidDef(pid: 0x0E, nameAr: 'تقديم الشرارة', unit: '°', bytes: 1, decode: (b) => b[0] / 2 - 64, min: -20, max: 50),
    PidDef(pid: pidControlVoltage, nameAr: 'فولت الكمبيوتر', unit: 'V', bytes: 2, decode: (b) => (b[0] * 256 + b[1]) / 1000, max: 16),
  ])
    p.pid: p,
};

/// Decodes a Mode 01 payload (starting 0x41 PID ...) into a value.
double? decodePid(List<int> data) {
  if (data.length < 3 || data[0] != 0x41) return null;
  final def = livePids[data[1]];
  if (def == null || data.length < 2 + def.bytes) return null;
  return def.decode(data.sublist(2, 2 + def.bytes));
}
