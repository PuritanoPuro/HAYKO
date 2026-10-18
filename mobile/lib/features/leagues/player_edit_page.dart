import 'package:flutter/material.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PlayerEditResult {
  const PlayerEditResult.saved(this.name, this.color) : deleted = false;
  const PlayerEditResult.deleted()
      : name = '',
        color = 0,
        deleted = true;

  final String name;
  final int color;
  final bool deleted;
}

class PlayerEditPage extends StatefulWidget {
  const PlayerEditPage(
      {super.key,
      required this.name,
      required this.color,
      this.deletionBlockedReason});

  final String name;
  final int color;
  final String? deletionBlockedReason;

  @override
  State<PlayerEditPage> createState() => _PlayerEditPageState();
}

class _PlayerEditPageState extends State<PlayerEditPage> {
  late final TextEditingController name;
  late int color;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.name);
    color = widget.color;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  String get colorHex =>
      '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void save() {
    final value = name.text.trim();
    if (value.isEmpty) {
      showError(context, 'Inserisci il nome del giocatore.');
      return;
    }
    Navigator.pop(context, PlayerEditResult.saved(value, color));
  }

  Future<void> delete() async {
    if (widget.deletionBlockedReason != null) {
      showError(context, widget.deletionBlockedReason!);
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Elimina giocatore'),
            content: Text('Vuoi eliminare ${widget.name} dalla lega?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Elimina')),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) {
      Navigator.pop(context, const PlayerEditResult.deleted());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            toolbarHeight: 64,
            title: const Text('Modifica giocatore',
                style: TextStyle(
                    fontSize: 20, height: 1.3, fontWeight: FontWeight.w700))),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                height: 76,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: HaykoColors.fieldSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HaykoColors.fieldLine)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nome giocatore',
                          style: TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600)),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('player-name-field'),
                          controller: name,
                          maxLength: 60,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                          decoration: const InputDecoration(
                              isDense: true,
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero),
                        ),
                      ),
                    ]),
              ),
              const SizedBox(height: 12),
              Material(
                color: HaykoColors.fieldSurface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const ValueKey('player-color-field'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final value = await chooseColor(context, color);
                    if (value != null && mounted) setState(() => color = value);
                  },
                  child: SizedBox(
                    height: 76,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Colore giocatore',
                                    style: TextStyle(
                                        color: HaykoColors.mutedText,
                                        fontSize: 12,
                                        height: 16 / 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(colorHex,
                                    style: const TextStyle(
                                        fontSize: 16, height: 1.5)),
                              ]),
                        ),
                        Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: Color(color), shape: BoxShape.circle)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AccountButton('Salva', onPressed: save),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: delete,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xffffb4ab),
                      backgroundColor: HaykoColors.fieldSurface,
                      side: const BorderSide(color: Color(0xffffb4ab)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontFamily: 'BricolageGrotesque',
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w700)),
                  child: const Text('Elimina giocatore'),
                ),
              ),
              const SizedBox(height: 12),
              AccountButton('Annulla',
                  outline: true, onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      );
}
