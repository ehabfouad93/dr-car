import 'dart:convert';

enum DtcStatus { stored, pending, permanent }

extension DtcStatusText on DtcStatus {
  String get labelAr => switch (this) {
        DtcStatus.stored => 'مسجّل (مؤكد)',
        DtcStatus.pending => 'ظهر مرة واحدة، لسه مش متأكد',
        DtcStatus.permanent => 'دائم: هيتمسح لوحده بعد ما العطل يتصلح ويتأكد',
      };
}

class FoundCode {
  FoundCode(this.code, this.status, this.module);
  final String code;
  final DtcStatus status;
  final String module;

  Map<String, dynamic> toJson() => {'code': code, 'status': status.name, 'module': module};
  factory FoundCode.fromJson(Map<String, dynamic> j) =>
      FoundCode(j['code'] as String, DtcStatus.values.byName(j['status'] as String), j['module'] as String);
}

class ScanResult {
  ScanResult({
    required this.time,
    required this.codes,
    required this.milOn,
    required this.modulesAnswered,
    required this.modulesSilent,
    this.freezeFrame = const {},
    this.batteryVolts,
    this.note = '',
  });

  final DateTime time;
  final List<FoundCode> codes;
  final bool milOn;
  final List<String> modulesAnswered;
  final List<String> modulesSilent;
  final Map<String, Object> freezeFrame;
  final double? batteryVolts;
  final String note;

  String toJsonString() => jsonEncode({
        'time': time.toIso8601String(),
        'codes': codes.map((c) => c.toJson()).toList(),
        'milOn': milOn,
        'answered': modulesAnswered,
        'silent': modulesSilent,
        'freeze': freezeFrame.map((k, v) => MapEntry(k, v.toString())),
        'volts': batteryVolts,
        'note': note,
      });

  factory ScanResult.fromJsonString(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return ScanResult(
      time: DateTime.parse(j['time'] as String),
      codes: (j['codes'] as List).map((e) => FoundCode.fromJson(e as Map<String, dynamic>)).toList(),
      milOn: j['milOn'] as bool,
      modulesAnswered: (j['answered'] as List).cast<String>(),
      modulesSilent: (j['silent'] as List).cast<String>(),
      freezeFrame: (j['freeze'] as Map<String, dynamic>).cast<String, Object>(),
      batteryVolts: (j['volts'] as num?)?.toDouble(),
      note: j['note'] as String? ?? '',
    );
  }
}
