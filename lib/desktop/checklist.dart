import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../services/storage.dart';

/// How an item is verified.
enum CheckKind {
  /// One-click probe that talks to the car.
  auto,

  /// A logger the user runs while doing something (fan, CNG).
  logger,

  /// Needs a definition file (DDT4ALL JSON) loaded in the modules screen.
  ddt,

  /// Done by hand on the car (ohmmeter, gauge, eyes); the user records the value.
  manual,
}

enum CheckState { todo, done, problem }

class CheckItem {
  CheckItem(this.id, this.titleAr, this.howAr, this.kind, {this.probe = ''});
  final int id;
  final String titleAr;
  final String howAr;
  final CheckKind kind;

  /// Which automatic probe answers it (see probes.dart).
  final String probe;

  CheckState state = CheckState.todo;
  String result = '';
  String notes = '';
  DateTime? at;

  Map<String, dynamic> toJson() => {'state': state.name, 'result': result, 'notes': notes, 'at': at?.toIso8601String()};

  void load(Map<String, dynamic> j) {
    state = CheckState.values.byName(j['state'] as String? ?? 'todo');
    result = j['result'] as String? ?? '';
    notes = j['notes'] as String? ?? '';
    at = j['at'] == null ? null : DateTime.tryParse(j['at'] as String);
  }
}

/// The "confirm on the real car" list from reports/Renault Logan 2015 diagnostics.md.
List<CheckItem> buildChecklist() => [
      CheckItem(1, 'الجيل: X52/L52 (لوجان 2) ولا لوجان 1؟',
          'الأداة بتجرب جدول عناوين لوجان 2 على CAN، وبتجرب K-line (طرف 7). اكتب رقم الشاسيه في الملاحظات.', CheckKind.auto,
          probe: 'platform'),
      CheckItem(2, 'الكمبيوترات اللي بترد', 'بنبعت 10C0 لكل العناوين على 500 وبعدين 250 kbps.', CheckKind.auto, probe: 'modules'),
      CheckItem(3, 'نوع كمبيوتر الموتور', 'رد 2180 من 7E0 (المورد، رقم القطعة، السوفت وير). قارنه بالتيكت اللي على الكمبيوتر.',
          CheckKind.auto,
          probe: 'modules'),
      CheckItem(4, 'نوع كمبيوتر الـ ABS والإيرباج والـ UCH والعداد', '2180، ولو 10C0 فشل: 22F18A / F194 / F195.', CheckKind.auto,
          probe: 'modules'),
      CheckItem(5, 'طريقة قراية الأعطال في كل كمبيوتر', 'بنجرب 1902AF وبعدين 17FF00 ونسجّل البايتات زي ما هي.', CheckKind.auto,
          probe: 'modules'),
      CheckItem(6, 'أكواد DF الحقيقية لكل كمبيوتر',
          'حمّل ملف تعريف كل كمبيوتر (DDT4ALL JSON) من صفحة "الكمبيوترات" وصدّر قايمة الأعطال.', CheckKind.ddt,
          probe: 'ddt_dtc'),
      CheckItem(7, 'القراءات اللي الموتور بيدعمها', '0100 / 0120 / 0140، و PID 1C (معيار الانبعاثات)، و 13 / 1D (حساس أكسجين خلفي).',
          CheckKind.auto,
          probe: 'pids'),
      CheckItem(8, 'حرارة تشغيل المروحة والثرموستات',
          'شغّل المسجّل، وسيب الموتور يسخن في الرالنتي، واضغط "المروحة اشتغلت" أول ما تسمع الريلاي. اعملها تاني والتكييف شغال.',
          CheckKind.logger,
          probe: 'fan'),
      CheckItem(9, 'أوامر اختبار المروحة والطرمبة والكانستر', 'من ملف تعريف كمبيوتر الموتور. جرّب المروحة والموتور مطفي.', CheckKind.ddt,
          probe: 'ddt_control'),
      CheckItem(10, 'أمر تصفير قيم التعلّم', 'من ملف تعريف كمبيوتر الموتور (قايمة RZ).', CheckKind.ddt, probe: 'ddt_control'),
      CheckItem(11, 'بايتات مسح الأعطال لكل كمبيوتر', 'امسح من صفحة الكمبيوترات واتأكد إن الرد 54.', CheckKind.ddt),
      CheckItem(12, 'الإيرباج بعد حادثة', 'من ملف التعريف بس. متجربش أبدًا على كمبيوتر مسجّل فيه حادثة.', CheckKind.ddt),
      CheckItem(13, 'صفحة حرارة مخفية في العداد', 'اضغط زرار التريب وانت بتدوّر الكونتاكت، واكتب اللي ظهر.', CheckKind.manual),
      CheckItem(14, 'نوع الدركسيون', 'في طرمبة دركسيون بسير؟ (الأداة بتشوف كمان لو العنوان 742 بيرد).', CheckKind.manual),
      CheckItem(15, 'حساس الـ ABS الخلفي والإيرباج الجانبي', 'الحساس الخلفي بيقرا من حلقة ممغنطة ولا ترس؟ في فيش إيرباج تحت الكراسي؟', CheckKind.manual),
      CheckItem(16, 'ضغط البنزين', 'ساعة ضغط على الرامب: 3.0 ولا 3.5 بار؟', CheckKind.manual),
      CheckItem(17, 'حساس الحرارة على 80 درجة', 'أفوميتر على الحساس والموتور سخن: 280 ولا 335 أوم؟', CheckKind.manual),
      CheckItem(18, 'قدرة القارئ', 'بنجرب كل أوامر AT اللي التطبيق محتاجها على القارئ ده.', CheckKind.auto, probe: 'adapter'),
      CheckItem(19, 'الغاز الطبيعي (CNG)', 'سجّل تصحيح البنزين دقيقتين على البنزين، ودقيقتين على الغاز.', CheckKind.logger, probe: 'cng'),
      CheckItem(20, 'مواعيد الصيانة', 'من كتيب صيانة رينو مصر أو التوكيل: الزيت، السير والطرمبة، البوجيهات، المياه.', CheckKind.manual),
    ];

class Checklist extends ChangeNotifier {
  Checklist() : items = buildChecklist();
  final List<CheckItem> items;

  CheckItem byId(int id) => items.firstWhere((i) => i.id == id);

  void update(int id, {CheckState? state, String? result, String? notes, bool appendResult = false}) {
    final i = byId(id);
    if (state != null) i.state = state;
    if (result != null) i.result = appendResult && i.result.isNotEmpty ? '${i.result}\n$result' : result;
    if (notes != null) i.notes = notes;
    i.at = DateTime.now();
    notifyListeners();
    save();
  }

  int get doneCount => items.where((i) => i.state != CheckState.todo).length;

  Future<File> _file() async => File('${(await appDataDir('LoganDoctor')).path}/logan_checklist.json');

  Future<void> load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final i in items) {
        final e = j['${i.id}'];
        if (e is Map<String, dynamic>) i.load(e);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> save() async {
    try {
      await (await _file()).writeAsString(jsonEncode({for (final i in items) '${i.id}': i.toJson()}));
    } catch (_) {}
  }

  /// Markdown report to send back for the fault guide / app updates.
  String exportMarkdown() {
    final b = StringBuffer('# Logan 2015 — real-car checklist\n\n');
    b.writeln('Exported ${DateTime.now().toIso8601String()} — $doneCount/${items.length} done\n');
    for (final i in items) {
      final mark = switch (i.state) { CheckState.done => '✅', CheckState.problem => '⚠️', CheckState.todo => '⬜' };
      b.writeln('## $mark ${i.id}. ${i.titleAr}');
      if (i.result.isNotEmpty) b.writeln('```\n${i.result}\n```');
      if (i.notes.isNotEmpty) b.writeln('Notes: ${i.notes}');
      b.writeln();
    }
    return b.toString();
  }
}
