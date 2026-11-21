import 'package:material_ui/material_ui.dart';

import '../data/dtc_repo.dart';

const brand = Color(0xFF0B5CAD);

ThemeData buildTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      useMaterial3: true,
      visualDensity: VisualDensity.comfortable,
    );

Color severityColor(Severity s) => switch (s) {
      Severity.stop => const Color(0xFFC62828),
      Severity.soon => const Color(0xFFEF6C00),
      Severity.drive => const Color(0xFF2E7D32),
    };

IconData severityIcon(Severity s) => switch (s) {
      Severity.stop => Icons.dangerous,
      Severity.soon => Icons.warning_amber,
      Severity.drive => Icons.check_circle,
    };

class SeverityChip extends StatelessWidget {
  const SeverityChip(this.s, {super.key});
  final Severity s;

  @override
  Widget build(BuildContext context) {
    final c = severityColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(severityIcon(s), size: 16, color: c),
        const SizedBox(width: 4),
        Text(s.labelAr, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 20, color: brand), const SizedBox(width: 6)],
          Text(text, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
        ]),
      );
}

class Bullets extends StatelessWidget {
  const Bullets(this.items, {super.key, this.numbered = false});
  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 22, child: Text(numbered ? '${i + 1}.' : '•')),
                Expanded(child: Text(items[i])),
              ]),
            ),
        ],
      );
}
