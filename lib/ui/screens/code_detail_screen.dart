import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../services/ai_service.dart';
import '../../services/app_state.dart';
import '../theme.dart';

class CodeDetailScreen extends StatefulWidget {
  const CodeDetailScreen({super.key, required this.found});
  final FoundCode found;

  @override
  State<CodeDetailScreen> createState() => _CodeDetailScreenState();
}

class _CodeDetailScreenState extends State<CodeDetailScreen> {
  final ai = AiService();
  final notesCtrl = TextEditingController();
  AiExplanation? answer;
  String? aiError;
  bool asking = false;

  Future<void> _ask(AppState app) async {
    setState(() {
      asking = true;
      aiError = null;
    });
    try {
      final a = await ai.explain(
        focusCode: widget.found.code,
        codes: app.lastScan?.codes ?? [widget.found],
        freezeFrame: app.lastScan?.freezeFrame ?? const {},
        liveSnapshot: app.liveSnapshot(),
        userNotes: notesCtrl.text,
      );
      setState(() => answer = a);
    } catch (e) {
      setState(() => aiError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final info = app.dtc.lookup(widget.found.code);
    final ff = app.lastScan?.freezeFrame ?? const {};
    return Scaffold(
      appBar: AppBar(title: Text(widget.found.code, textDirection: TextDirection.ltr)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(info.nameAr, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [SeverityChip(info.severity), const SizedBox(width: 8), Flexible(child: Text(widget.found.status.labelAr, style: const TextStyle(fontSize: 12)))]),
        if (info.renaultDf.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('كود رينو: ${info.renaultDf.replaceAll('?', ' (محتاج تأكيد)')}', style: const TextStyle(color: Colors.grey)),
          ),
        const SizedBox(height: 12),
        Text(info.descAr, style: const TextStyle(fontSize: 16)),
        if (info.loganNoteAr.isNotEmpty)
          Card(
            color: Colors.blue.shade50,
            margin: const EdgeInsets.only(top: 12),
            child: Padding(padding: const EdgeInsets.all(12), child: Text('🚗 في اللوجان: ${info.loganNoteAr}')),
          ),
        if (info.causesAr.isNotEmpty) ...[const SectionTitle('الأسباب المحتملة (الأرجح الأول)', icon: Icons.manage_search), Bullets(info.causesAr, numbered: true)],
        if (info.checksAr.isNotEmpty) ...[const SectionTitle('افحص الأول (رخيص)', icon: Icons.fact_check), Bullets(info.checksAr)],
        if (info.fixAr.isNotEmpty) ...[const SectionTitle('خطوات التصليح', icon: Icons.build), Bullets(info.fixAr, numbered: true)],
        if (info.partsAr.isNotEmpty) ...[const SectionTitle('قطع غيار ممكن تحتاجها', icon: Icons.shopping_bag), Bullets(info.partsAr)],
        if (ff.isNotEmpty) ...[
          const SectionTitle('حالة العربية لحظة العطل (Freeze Frame)', icon: Icons.photo_camera),
          for (final e in ff.entries) Text('${e.key}: ${e.value}'),
        ],
        const Divider(height: 32),
        const SectionTitle('اشرحلي بالذكاء الاصطناعي', icon: Icons.auto_awesome),
        TextField(
          controller: notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'اكتب اللي بتحس بيه (مثال: المروحة شغالة على طول، صعبة في الدوران الصبح)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: asking ? null : () => _ask(app),
          icon: asking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
          label: const Text('اشرحلي'),
        ),
        if (aiError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(aiError!, style: const TextStyle(color: Colors.red))),
        if (answer != null) _aiCard(answer!),
        const SizedBox(height: 24),
        const Text('⚖️ التطبيق بيرشدك بس، والميكانيكي هو اللي يقرر. ده تشخيص مبدئي "غالبًا" ومش أكيد.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }

  Widget _aiCard(AiExplanation a) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.meaning, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SectionTitle('الأسباب الأرجح'),
            Bullets(a.likelyCauses, numbered: true),
            const SectionTitle('افحص الأول'),
            Bullets(a.cheapChecks),
            const SectionTitle('قول للميكانيكي'),
            Text(a.tellMechanic),
            if (a.links.isNotEmpty) ...[const SectionTitle('علاقة الأكواد ببعض'), Bullets(a.links)],
          ]),
        ),
      );
}
