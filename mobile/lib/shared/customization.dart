import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';

Color contrastColor(int color) =>
    Color(color).computeLuminance() > 0.45 ? Colors.black : Colors.white;
ThemeData leagueTheme(BuildContext context, League l) {
  final base = Theme.of(context);
  // La personalizzazione conserva i suoi accenti senza rigenerare lo sfondo
  // e i pulsanti del tema globale HAYKO.
  return base.copyWith(
    navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: Color(l.secondaryColor).withValues(alpha: 0.25)),
    colorScheme: base.colorScheme.copyWith(
        secondary: Color(l.secondaryColor),
        onSecondary: contrastColor(l.secondaryColor)),
  );
}

class ColorChoice extends StatelessWidget {
  final String label;
  final int color;
  final ValueChanged<int> changed;
  const ColorChoice(
      {super.key,
      required this.label,
      required this.color,
      required this.changed});
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      leading: CircleAvatar(radius: 14, backgroundColor: Color(color)),
      trailing: const Icon(Icons.palette),
      onTap: () async {
        final value = await chooseColor(context, color);
        if (!context.mounted) return;
        if (value != null) changed(value);
      });
}

Future<int?> chooseColor(BuildContext context, int initial) async {
  const palette = [
    0xffbbf568,
    0xff8ebcff,
    0xffffab64,
    0xffff6b6b,
    0xffa78bfa,
    0xff38d9a9,
    0xfff7d154,
    0xfff78fc1,
    0xff40c9ff,
    0xffeeeeee,
    0xff343a40,
    0xff005f73
  ];
  var selected = initial;
  final hex = TextEditingController(
      text:
          initial.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase());
  final result = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => AlertDialog(
                  title: const Text('Scegli colore'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      for (final value in palette)
                        InkWell(
                            onTap: () => set(() {
                                  selected = value;
                                  hex.text = value
                                      .toRadixString(16)
                                      .padLeft(8, '0')
                                      .substring(2)
                                      .toUpperCase();
                                }),
                            child: CircleAvatar(
                                backgroundColor: Color(value),
                                child: selected == value
                                    ? Icon(Icons.check,
                                        color: contrastColor(value))
                                    : null))
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                        controller: hex,
                        maxLength: 6,
                        decoration: const InputDecoration(
                            labelText: 'Colore personalizzato',
                            prefixText: '#',
                            helperText: 'Sei cifre: ad esempio FF8800')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Annulla')),
                    FilledButton(
                        onPressed: () {
                          final value =
                              int.tryParse(hex.text.trim(), radix: 16);
                          if (RegExp(r'^[0-9a-fA-F]{6}$')
                                  .hasMatch(hex.text.trim()) &&
                              value != null) {
                            Navigator.pop(c, 0xff000000 | value);
                          }
                        },
                        child: const Text('Seleziona'))
                  ])));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  hex.dispose();
  return result;
}

class IdentityEdit {
  final String name;
  final int color;
  final int? secondary;
  IdentityEdit(this.name, this.color, this.secondary);
}

Future<IdentityEdit?> editIdentity(
    BuildContext context, String title, String name, int color,
    {int? secondary}) async {
  final text = TextEditingController(text: name);
  var primary = color, second = secondary;
  final result = await showDialog<IdentityEdit>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => AlertDialog(
                  title: Text(title),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: text,
                        maxLength: 60,
                        decoration: const InputDecoration(labelText: 'Nome')),
                    ColorChoice(
                        label: secondary == null ? 'Colore' : 'Colore primario',
                        color: primary,
                        changed: (v) => set(() => primary = v)),
                    if (second != null)
                      ColorChoice(
                          label: 'Colore secondario',
                          color: second!,
                          changed: (v) => set(() => second = v)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Annulla')),
                    FilledButton(
                        onPressed: () {
                          if (text.text.trim().isNotEmpty) {
                            Navigator.pop(
                                c,
                                IdentityEdit(
                                    text.text.trim(), primary, second));
                          }
                        },
                        child: const Text('Salva'))
                  ])));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  text.dispose();
  return result;
}

String dateLabel(String? value) {
  if (value == null) return 'Data e ora non indicate';
  final d = DateTime.parse(value).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
}

class EventDetailsFields extends StatelessWidget {
  final DateTime date;
  final TextEditingController venue;
  final ValueChanged<DateTime> changed;
  const EventDetailsFields(
      {super.key,
      required this.date,
      required this.venue,
      required this.changed});
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text('${date.day}/${date.month}/${date.year}'),
                  onPressed: () async {
                    final value = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (!context.mounted) return;
                    if (value != null) {
                      changed(DateTime(value.year, value.month, value.day,
                          date.hour, date.minute));
                    }
                  })),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(
                      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
                  onPressed: () async {
                    final value = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(date));
                    if (!context.mounted) return;
                    if (value != null) {
                      changed(DateTime(date.year, date.month, date.day,
                          value.hour, value.minute));
                    }
                  }))
        ]),
        TextField(
            key: const ValueKey('event-venue'),
            controller: venue,
            maxLength: 120,
            decoration: const InputDecoration(
                labelText: 'Luogo / campo (facoltativo)')),
        const Text('L’evento si avvia soltanto premendo Inizia partita.'),
      ]);
}
