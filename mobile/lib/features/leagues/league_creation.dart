import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class LeagueCreation extends StatefulWidget {
  const LeagueCreation({super.key});

  @override
  State<LeagueCreation> createState() => _LeagueCreationState();
}

class _LeagueCreationState extends State<LeagueCreation> {
  final name = TextEditingController();
  String type = 'amateur', kind = 'league';
  int format = 5;
  bool doubleLeg = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void submit() {
    if (name.text.trim().isEmpty) {
      showError(context, 'Inserisci il nome della lega.');
      return;
    }
    final l = League(newId(), name.text.trim(), [], [], type: type);
    if (type == 'competition') {
      l.competitions.add(Competition(
          newId(), name.text.trim(), kind, format, [],
          doubleLeg: kind == 'league' && doubleLeg, allowDraft: true));
    }
    Navigator.pop(context, l);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        leadingWidth: 52,
        leading: IconButton(
            tooltip: 'Indietro',
            icon: const Icon(Icons.arrow_back, size: 24),
            onPressed: () => Navigator.maybePop(context)),
        titleSpacing: 0,
        title: const Text('Nuova lega',
            style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 20,
                height: 26 / 20,
                fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _LeagueNameField(controller: name),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _TypeChip(
                      label: 'Amatoriale',
                      selected: type == 'amateur',
                      onTap: () => setState(() => type = 'amateur'))),
              const SizedBox(width: 8),
              Expanded(
                  child: _TypeChip(
                      label: 'Competizione',
                      selected: type == 'competition',
                      onTap: () => setState(() => type = 'competition'))),
            ]),
            const SizedBox(height: 12),
            if (type == 'amateur')
              const Text(
                  'Un gruppo di amici: partite, giocatori e statistiche.',
                  style: TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 16,
                      height: 1.5,
                      color: HaykoColors.mutedText)),
            if (type == 'competition') ...[
              DropdownButton<String>(
                  value: kind,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'league', child: Text('Campionato')),
                    DropdownMenuItem(
                        value: 'knockout', child: Text('Torneo a eliminazione'))
                  ],
                  onChanged: (v) => setState(() => kind = v!)),
              if (kind == 'league')
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Andata e ritorno'),
                    subtitle: Text(doubleLeg
                        ? 'Ogni coppia si incontra due volte'
                        : 'Solo andata: ogni coppia si incontra una volta'),
                    value: doubleLeg,
                    onChanged: (v) => setState(() => doubleLeg = v)),
              DropdownButton<int>(
                  value: format,
                  isExpanded: true,
                  items: [
                    for (var n = 2; n <= 11; n++)
                      DropdownMenuItem(value: n, child: Text('${n}v$n'))
                  ],
                  onChanged: (v) => setState(() => format = v!)),
              const Text(
                  'Dopo la creazione aggiungi le squadre, i giocatori e i numeri di maglia nella sezione Squadre.'),
            ],
            const SizedBox(height: 12),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: HaykoColors.chalk,
                    foregroundColor: HaykoColors.fieldBackground,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w700)),
                onPressed: submit,
                child: const Text('Crea lega')),
          ],
        ),
      ));
}

class _LeagueNameField extends StatelessWidget {
  const _LeagueNameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(color: HaykoColors.fieldLine),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nome lega',
              style: TextStyle(
                  fontFamily: 'BricolageGrotesque',
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: HaykoColors.mutedText)),
          const SizedBox(height: 8),
          Expanded(
              child: TextField(
            controller: controller,
            maxLength: 60,
            style: const TextStyle(
                fontFamily: 'BricolageGrotesque', fontSize: 16, height: 1.5),
            decoration: const InputDecoration(
                isDense: true,
                hintText: 'Inserisci il nome',
                counterText: '',
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none),
          )),
        ]),
      );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? HaykoColors.fieldLine : HaykoColors.fieldBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: HaykoColors.fieldLine)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            child: Center(
                child: Text(label,
                    style: const TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600))),
          ),
        ),
      ));
}
