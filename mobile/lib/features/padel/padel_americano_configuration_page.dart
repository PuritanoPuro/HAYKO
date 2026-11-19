import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelAmericanoConfigurationPage extends StatefulWidget {
  const PadelAmericanoConfigurationPage({
    super.key,
    required this.initialName,
  });

  final String initialName;

  @override
  State<PadelAmericanoConfigurationPage> createState() =>
      _PadelAmericanoConfigurationPageState();
}

class _PadelAmericanoConfigurationPageState
    extends State<PadelAmericanoConfigurationPage> {
  late final TextEditingController name =
      TextEditingController(text: widget.initialName);
  int playerCount = 8;
  int courts = 2;
  int rounds = 7;
  int targetPoints = 24;
  bool rotatingPairs = true;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void create() {
    if (name.text.trim().isEmpty) {
      showError(context, 'Inserisci il nome della competizione.');
      return;
    }
    final competition = Competition(
      newId(),
      name.text.trim(),
      'americano',
      2,
      const [],
      americanoPlayerCount: playerCount,
      americanoCourts: courts,
      americanoRounds: rounds,
      americanoTargetPoints: targetPoints,
      americanoRotatingPairs: rotatingPairs,
      allowDraft: true,
    );
    final league = League(
      newId(),
      name.text.trim(),
      [],
      [],
      type: 'competition',
      sport: LeagueSport.padel,
      primaryColor: HaykoColors.padelAccent.toARGB32(),
      competitions: [competition],
    );
    Navigator.pop(context, league);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          centerTitle: false,
          title: const Text('Configura Americano'),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            key: const ValueKey('padel-americano-configuration'),
            padding: const EdgeInsets.all(24),
            children: [
              _AmericanoNameField(controller: name),
              const SizedBox(height: 12),
              _AmericanoDropdown<int>(
                label: 'Numero giocatori',
                value: playerCount,
                items: [
                  for (final value in const [4, 8, 12, 16, 20, 24])
                    DropdownMenuItem(
                      value: value,
                      child: Text('$value giocatori'),
                    ),
                ],
                onChanged: (value) => setState(() {
                  playerCount = value!;
                  courts = courts.clamp(1, playerCount ~/ 4);
                }),
              ),
              const SizedBox(height: 12),
              _AmericanoDropdown<int>(
                label: 'Campi disponibili',
                value: courts,
                items: [
                  for (var value = 1; value <= playerCount ~/ 4; value++)
                    DropdownMenuItem(
                      value: value,
                      child: Text('$value ${value == 1 ? 'campo' : 'campi'}'),
                    ),
                ],
                onChanged: (value) => setState(() => courts = value!),
              ),
              const SizedBox(height: 12),
              _AmericanoDropdown<int>(
                label: 'Turni',
                value: rounds,
                items: [
                  for (var value = 3; value <= 15; value += 2)
                    DropdownMenuItem(
                      value: value,
                      child: Text('$value turni'),
                    ),
                ],
                onChanged: (value) => setState(() => rounds = value!),
              ),
              const SizedBox(height: 12),
              _RotationField(
                value: rotatingPairs,
                onChanged: (value) => setState(() => rotatingPairs = value),
              ),
              const SizedBox(height: 12),
              _AmericanoDropdown<int>(
                label: 'Formato incontro',
                value: targetPoints,
                items: const [
                  DropdownMenuItem(value: 16, child: Text('16 punti totali')),
                  DropdownMenuItem(value: 24, child: Text('24 punti totali')),
                  DropdownMenuItem(value: 32, child: Text('32 punti totali')),
                ],
                onChanged: (value) => setState(() => targetPoints = value!),
              ),
              const SizedBox(height: 12),
              const Text(
                'Dopo la creazione seleziona i giocatori: il calendario '
                'genera automaticamente coppie e avversari.',
                style: TextStyle(
                  color: HaykoColors.mutedText,
                  fontSize: 14,
                  height: 20 / 14,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('create-padel-americano'),
                onPressed: create,
                style: FilledButton.styleFrom(
                  backgroundColor: HaykoColors.chalk,
                  foregroundColor: HaykoColors.fieldBackground,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Crea Americano'),
              ),
            ],
          ),
        ),
      );
}

class _AmericanoNameField extends StatelessWidget {
  const _AmericanoNameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(
            color: HaykoColors.padelAccent.withValues(alpha: .42),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nome competizione',
                style: TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600)),
            Expanded(
              child: TextField(
                controller: controller,
                maxLength: 60,
                style: const TextStyle(fontSize: 16, height: 24 / 16),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
      );
}

class _AmericanoDropdown<T> extends StatelessWidget {
  const _AmericanoDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(
            color: HaykoColors.padelAccent.withValues(alpha: .42),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: HaykoColors.mutedText,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isExpanded: true,
                  dropdownColor: HaykoColors.fieldSurface,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      );
}

class _RotationField extends StatelessWidget {
  const _RotationField({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 66,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(
            color: HaykoColors.padelAccent.withValues(alpha: .30),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coppie a rotazione',
                      style: TextStyle(fontSize: 16, height: 24 / 16)),
                  Text(
                    'Ogni giocatore cambia compagno a ogni turno',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}
