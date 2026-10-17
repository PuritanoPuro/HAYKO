import 'package:flutter/material.dart';

typedef Save = Future<void> Function();

String statusName(String s) =>
    {
      'scheduled': 'Programmata',
      'live': 'In corso',
      'finished': 'Terminata'
    }[s] ??
    s;
void showError(BuildContext context, Object e) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(e.toString())));
Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
        context: context,
        builder: (c) =>
            AlertDialog(title: Text(title), content: Text(body), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Indietro')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Conferma'))
            ])) ??
    false;
Future<String?> askText(BuildContext context, String title,
    {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: controller, autofocus: true, maxLength: 60),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Annulla')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.pop(c, controller.text.trim());
                      }
                    },
                    child: const Text('Salva'))
              ]));
  // Il controller resta valido fino alla chiusura dell'animazione del dialogo.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}
