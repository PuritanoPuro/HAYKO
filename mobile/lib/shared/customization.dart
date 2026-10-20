import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/ui.dart';

Color contrastColor(int color) =>
    Color(color).computeLuminance() > 0.45 ? Colors.black : Colors.white;
ThemeData leagueTheme(BuildContext context, League l) {
  final base = Theme.of(context);
  // La personalizzazione conserva i suoi accenti senza rigenerare lo sfondo
  // e i pulsanti del tema globale HAYKO.
  return base.copyWith(
    navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: Color(l.primaryColor).withValues(alpha: 0.25)),
    colorScheme: base.colorScheme.copyWith(
        secondary: Color(l.primaryColor),
        onSecondary: contrastColor(l.primaryColor)),
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
          builder: (c, set) => HaykoDialog(
                  title: 'Scegli colore',
                  content: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        for (final value in palette)
                          InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => set(() {
                                    selected = value;
                                    hex.text = value
                                        .toRadixString(16)
                                        .padLeft(8, '0')
                                        .substring(2)
                                        .toUpperCase();
                                  }),
                              child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                      color: Color(value),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: selected == value
                                              ? HaykoColors.chalk
                                              : HaykoColors.fieldLine,
                                          width: selected == value ? 3 : 1)),
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
                  ),
                  actions: [
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
                        child: const Text('Seleziona')),
                    OutlinedButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Annulla')),
                  ])));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  hex.dispose();
  return result;
}

class IdentityEdit {
  final String name;
  final int color;
  IdentityEdit(this.name, this.color);
}

Future<IdentityEdit?> editIdentity(
    BuildContext context, String title, String name, int color) async {
  final text = TextEditingController(text: name);
  var primary = color;
  final result = await showDialog<IdentityEdit>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => HaykoDialog(
                  title: title,
                  content: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: text,
                          maxLength: 60,
                          decoration: const InputDecoration(labelText: 'Nome')),
                      ColorChoice(
                          label: 'Colore',
                          color: primary,
                          changed: (v) => set(() => primary = v)),
                    ])),
                  ),
                  actions: [
                    FilledButton(
                        onPressed: () {
                          if (text.text.trim().isNotEmpty) {
                            Navigator.pop(
                                c, IdentityEdit(text.text.trim(), primary));
                          }
                        },
                        child: const Text('Salva')),
                    OutlinedButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Annulla')),
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

Future<TimeOfDay?> chooseHaykoTime(
    BuildContext context, TimeOfDay initial) async {
  var hour = initial.hour;
  var minute = initial.minute;
  final hourController = FixedExtentScrollController(initialItem: hour);
  final minuteController = FixedExtentScrollController(initialItem: minute);
  final result = await showDialog<TimeOfDay>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => HaykoDialog(
                title: 'Seleziona orario',
                content: Material(
                  color: Colors.transparent,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Row(children: [
                      Expanded(
                          child: Text('Ore',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: HaykoColors.mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                      SizedBox(width: 24),
                      Expanded(
                          child: Text('Minuti',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: HaykoColors.mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 176,
                      child: Row(children: [
                        Expanded(
                            child: _TimeWheel(
                                controller: hourController,
                                count: 24,
                                onChanged: (value) =>
                                    setState(() => hour = value))),
                        const SizedBox(
                            width: 24,
                            child: Center(
                                child: Text(':',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700)))),
                        Expanded(
                            child: _TimeWheel(
                                controller: minuteController,
                                count: 60,
                                onChanged: (value) =>
                                    setState(() => minute = value))),
                      ]),
                    ),
                  ]),
                ),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(
                          dialogContext, TimeOfDay(hour: hour, minute: minute)),
                      child: const Text('Conferma')),
                  OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Annulla')),
                ],
              )));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  hourController.dispose();
  minuteController.dispose();
  return result;
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel(
      {required this.controller, required this.count, required this.onChanged});

  final FixedExtentScrollController controller;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => CupertinoPicker.builder(
        scrollController: controller,
        itemExtent: 44,
        useMagnifier: true,
        magnification: 1.08,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
            background: HaykoColors.fieldLine.withValues(alpha: 0.72)),
        onSelectedItemChanged: onChanged,
        childCount: count,
        itemBuilder: (context, index) => Center(
          child: Text(index.toString().padLeft(2, '0'),
              style: const TextStyle(
                  color: HaykoColors.chalk,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
        ),
      );
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
                    final value = await chooseHaykoTime(
                        context, TimeOfDay.fromDateTime(date));
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
