import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../services/app_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return FutureBuilder<List<ScanResult>>(
      future: app.history.all(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) return const Center(child: Text('لسه مفيش سكانات محفوظة.'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final s = list[i];
            final t = s.time;
            return Card(
              child: ListTile(
                leading: Icon(s.codes.isEmpty ? Icons.check_circle : Icons.warning_amber, color: s.codes.isEmpty ? Colors.green : Colors.orange),
                title: Text(s.codes.isEmpty ? 'مفيش أعطال' : s.codes.map((c) => c.code).join('  '), textDirection: TextDirection.ltr),
                subtitle: Text('${t.year}/${t.month}/${t.day}  ${t.hour}:${t.minute.toString().padLeft(2, '0')}'
                    '${s.batteryVolts != null ? '  •  ${s.batteryVolts!.toStringAsFixed(1)}V' : ''}'
                    '${s.note.isNotEmpty ? '  •  ${s.note}' : ''}'),
              ),
            );
          },
        );
      },
    );
  }
}
