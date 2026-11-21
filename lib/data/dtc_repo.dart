import 'dart:convert';

/// Safe to drive / fix this week / stop now.
enum Severity { drive, soon, stop }

extension SeverityText on Severity {
  String get labelAr => switch (this) {
        Severity.drive => 'آمن تسوق',
        Severity.soon => 'صلّح خلال أسبوع',
        Severity.stop => 'وقّف العربية',
      };
  int get rank => switch (this) { Severity.stop => 0, Severity.soon => 1, Severity.drive => 2 };
}

class DtcInfo {
  DtcInfo({
    required this.code,
    required this.nameAr,
    required this.descAr,
    required this.severity,
    this.causesAr = const [],
    this.checksAr = const [],
    this.fixAr = const [],
    this.partsAr = const [],
    this.loganNoteAr = '',
    this.inGuide = true,
    this.renaultDf = '',
  });

  final String code;
  final String nameAr;
  final String descAr;
  final Severity severity;
  final List<String> causesAr;
  final List<String> checksAr;
  final List<String> fixAr;
  final List<String> partsAr;
  final String loganNoteAr;

  /// False when we only have the generic family text for this code.
  final bool inGuide;

  /// Renault DF number on the K7M ECU; a trailing '?' means sources conflict.
  final String renaultDf;
}

/// Offline Logan 2015 K7M fault guide, loaded from assets/logan_dtc.json.
class DtcRepo {
  DtcRepo(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    _codes = (m['codes'] as Map<String, dynamic>).cast<String, Map<String, dynamic>>();
    _families = (m['families_ar'] as Map<String, dynamic>).cast<String, String>();
  }

  late final Map<String, Map<String, dynamic>> _codes;
  late final Map<String, String> _families;

  int get size => _codes.length;

  DtcInfo lookup(String code) {
    final e = _codes[code];
    if (e != null) {
      List<String> l(String k) => (e[k] as List).cast<String>();
      return DtcInfo(
        code: code,
        nameAr: e['name_ar'] as String,
        descAr: e['desc_ar'] as String,
        severity: Severity.values.byName(e['severity'] as String),
        causesAr: l('causes_ar'),
        checksAr: l('checks_ar'),
        fixAr: l('fix_ar'),
        partsAr: l('parts_ar'),
        loganNoteAr: e['logan_note_ar'] as String,
        renaultDf: e['renault_df'] as String? ?? '',
      );
    }
    // Never show "no description": fall back to the code family.
    final family = _families[code.substring(0, 3)] ?? _families[code.substring(0, 2)] ?? _families[code[0]] ?? 'عطل غير معروف';
    return DtcInfo(
      code: code,
      nameAr: family,
      descAr: 'الكود ده مش في دليل اللوجان لسه. ده الوصف العام لعيلة الكود. '
          'استخدم زرار "اشرحلي بالذكاء الاصطناعي" عشان تعرف أكتر، واسأل الميكانيكي.',
      // Unknown codes: treat as "fix soon" until a mechanic says otherwise.
      severity: Severity.soon,
      inGuide: false,
    );
  }
}
