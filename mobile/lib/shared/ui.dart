import 'package:flutter/material.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

typedef Save = Future<void> Function();

String statusName(String s) =>
    {
      'scheduled': 'Programmata',
      'live': 'In corso',
      'finished': 'Terminata'
    }[s] ??
    s;

class HaykoDialog extends StatelessWidget {
  const HaykoDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 342),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(color: HaykoColors.fieldLine),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            Flexible(child: content),
            const SizedBox(height: 20),
            for (var index = 0; index < actions.length; index++) ...[
              SizedBox(
                  width: double.infinity, height: 52, child: actions[index]),
              if (index < actions.length - 1) const SizedBox(height: 8),
            ],
          ]),
        ),
      );
}

void showError(BuildContext context, Object e) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Row(children: [
        const Icon(Icons.error_outline, color: HaykoColors.chalk),
        const SizedBox(width: 12),
        Expanded(child: Text(e.toString())),
      ])));
Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
        context: context,
        builder: (c) => HaykoDialog(
                title: title,
                content: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(body,
                        style: const TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 14,
                            height: 20 / 14))),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Conferma')),
                  OutlinedButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Indietro')),
                ])) ??
    false;
Future<String?> askText(BuildContext context, String title,
    {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
      context: context,
      builder: (c) => HaykoDialog(
              title: title,
              content: Material(
                color: Colors.transparent,
                child: TextField(
                    controller: controller, autofocus: true, maxLength: 60),
              ),
              actions: [
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.pop(c, controller.text.trim());
                      }
                    },
                    child: const Text('Salva')),
                OutlinedButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Annulla')),
              ]));
  // Il controller resta valido fino alla chiusura dell'animazione del dialogo.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}
