import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';

/// Backend config, passed at build time:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=...
/// The Claude API key lives ONLY in the Supabase edge function, never here.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const carProfile = {
  'make': 'Renault',
  'model': 'Logan',
  'year': 2015,
  'engine': 'K7M 1.6 8v petrol',
  'gearbox': 'manual (JH3)',
};

class AiExplanation {
  AiExplanation.fromJson(Map<String, dynamic> j)
      : meaning = j['meaning'] as String,
        likelyCauses = (j['likely_causes'] as List).cast<String>(),
        cheapChecks = (j['cheap_checks'] as List).cast<String>(),
        urgency = j['urgency'] as String,
        tellMechanic = j['tell_mechanic'] as String,
        links = (j['links_between_codes'] as List).cast<String>();

  final String meaning;
  final List<String> likelyCauses;
  final List<String> cheapChecks;
  final String urgency; // drive | soon | stop
  final String tellMechanic;
  final List<String> links;
}

class AiService {
  bool get configured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  Future<AiExplanation> explain({
    required String focusCode,
    required List<FoundCode> codes,
    required Map<String, Object> freezeFrame,
    required Map<String, double> liveSnapshot,
    required String userNotes,
  }) async {
    if (!configured) {
      throw Exception('الشرح بالذكاء الاصطناعي مش متفعل في النسخة دي.');
    }
    final res = await http
        .post(
          Uri.parse('$supabaseUrl/functions/v1/explain-code'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $supabaseAnonKey',
            'apikey': supabaseAnonKey,
          },
          body: jsonEncode({
            'car': carProfile,
            'focus_code': focusCode,
            'codes': codes.map((c) => c.toJson()).toList(),
            'freeze_frame': freezeFrame.map((k, v) => MapEntry(k, v.toString())),
            'live': liveSnapshot,
            'user_notes': userNotes,
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw Exception('الشرح مش متاح دلوقتي (${res.statusCode}). جرب تاني بعد شوية.');
    }
    return AiExplanation.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }
}
