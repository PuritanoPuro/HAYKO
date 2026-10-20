import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/ui.dart';

/// The code has already been copied when this dialog opens. The explicit
/// action lets the user copy it again without generating another invitation.
Future<void> showInviteCodeDialog(BuildContext context, String code) async {
  final copied = await showDialog<bool>(
    context: context,
    builder: (_) => InviteCodeDialog(code: code),
  );
  if (copied == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codice invito copiato')),
    );
  }
}

class InviteCodeDialog extends StatefulWidget {
  const InviteCodeDialog({super.key, required this.code});

  final String code;

  @override
  State<InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<InviteCodeDialog> {
  bool copying = false;
  String? error;

  Future<void> copy() async {
    if (copying) return;
    setState(() {
      copying = true;
      error = null;
    });
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          copying = false;
          error = 'Copia non riuscita. Riprova o seleziona il codice.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => HaykoDialog(
        title: 'Codice invito copiato',
        content: Material(
          color: Colors.transparent,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                  color: HaykoColors.fieldBackground,
                  border: Border.all(color: HaykoColors.fieldLine),
                  borderRadius: BorderRadius.circular(12)),
              child: SelectableText(widget.code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
            ),
            const SizedBox(height: 16),
            const Text(
                'Valido per 7 giorni. Chi lo usa invia una richiesta di accesso da approvare.',
                style:
                    TextStyle(color: HaykoColors.mutedText, height: 20 / 14)),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(error!),
            ],
          ]),
        ),
        actions: [
          FilledButton.icon(
            onPressed: copying ? null : copy,
            icon: const Icon(Icons.copy),
            label: const Text('Copia codice'),
          ),
          OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi')),
        ],
      );
}
