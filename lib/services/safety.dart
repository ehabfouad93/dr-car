/// Safety rules from the plan. Reading is always allowed; anything that
/// changes the car goes through here.
library;

class SafetyDecision {
  const SafetyDecision.allow() : allowed = true, reasonAr = '';
  const SafetyDecision.block(this.reasonAr) : allowed = false;
  final bool allowed;
  final String reasonAr;
}

/// Things the app will never do, whatever the UI asks for.
const forbiddenActionsAr = [
  'برمجة أو تعديل خريطة كمبيوتر الموتور (تيونينج)',
  'تغيير سوفت وير العداد أو الكمبيوتر',
  'تعديل الكيلومترات',
  'إطفاء لمبة الإيرباج أو الـ ABS من غير تصليح',
];

/// Blocked OBD services: 0x27 security access, 0x2E write data,
/// 0x31 routine control, 0x34-0x37 download/upload (flashing), 0x3B KWP write.
final _blockedPrefixes = ['27', '2E', '31', '34', '35', '36', '37', '3B', '3D'];

class SafetyGuard {
  /// Any write (clear codes, actuator test, setting change) needs speed == 0.
  SafetyDecision canWrite({required double? speedKmh}) {
    if (speedKmh == null) {
      return const SafetyDecision.block('مش قادرين نقرا السرعة. اقف بالعربية الأول وجرب تاني.');
    }
    if (speedKmh > 0) {
      return const SafetyDecision.block('العربية ماشية. أي أمر بيغيّر حاجة في العربية ممنوع وهي ماشية.');
    }
    return const SafetyDecision.allow();
  }

  /// Last line of defence: refuse raw commands that flash or write the ECU.
  /// [rawFrame]: the reader is in raw CAN mode (AT CAF0), so the first byte is
  /// an ISO-TP length byte, e.g. "022701"; check the service after it too.
  bool isForbiddenCommand(String cmd, {bool rawFrame = false}) {
    final c = cmd.replaceAll(' ', '').toUpperCase();
    if (c.startsWith('AT') || c.startsWith('ST')) return false;
    if (_blockedPrefixes.any(c.startsWith)) return true;
    final pci = rawFrame && c.length >= 4 ? int.tryParse(c.substring(0, 2), radix: 16) : null;
    if (pci != null) {
      final type = pci >> 4;
      if (type == 0 || type == 1) {
        final body = c.substring(type == 0 ? 2 : 4);
        if (_blockedPrefixes.any(body.startsWith)) return true;
      }
    }
    return false;
  }

  static const clearWarningAr = 'صلّحت سبب العطل؟ مسح الأكواد بيمسح الدليل اللي الميكانيكي محتاجه.\n\n'
      'هنحفظ نسخة من السكان الحالي قبل المسح. الأفضل الكونتاكت يكون شغال والموتور مطفي.';
}
