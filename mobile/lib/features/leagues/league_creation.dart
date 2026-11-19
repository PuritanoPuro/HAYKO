import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_configuration_page.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class LeagueCreation extends StatefulWidget {
  const LeagueCreation(
      {super.key,
      this.initialType = 'amateur',
      this.initialSport = LeagueSport.football});

  final String initialType;
  final String initialSport;

  @override
  State<LeagueCreation> createState() => _LeagueCreationState();
}

class _LeagueCreationState extends State<LeagueCreation> {
  final name = TextEditingController();
  late String type;
  late String sport;
  String kind = 'league';
  int format = 5;
  bool doubleLeg = false;

  @override
  void initState() {
    super.initState();
    type = widget.initialType;
    sport = LeagueSport.normalize(widget.initialSport);
    if (sport == LeagueSport.padel && type == 'competition') {
      doubleLeg = true;
      format = 3;
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty) {
      showError(context, 'Inserisci il nome della lega.');
      return;
    }
    if (sport == LeagueSport.padel &&
        type == 'competition' &&
        kind == 'americano') {
      final league = await Navigator.push<League>(
        context,
        MaterialPageRoute(
          builder: (_) => PadelAmericanoConfigurationPage(
            initialName: name.text.trim(),
          ),
        ),
      );
      if (mounted && league != null) Navigator.pop(context, league);
      return;
    }
    final l = League(newId(), name.text.trim(), [], [],
        type: type,
        sport: sport,
        primaryColor: sport == LeagueSport.padel
            ? HaykoColors.padelAccent.toARGB32()
            : 0xffbbf568);
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
        centerTitle: sport != LeagueSport.padel,
        leadingWidth: 52,
        leading: IconButton(
            tooltip: 'Indietro',
            icon: const Icon(Icons.arrow_back, size: 24),
            onPressed: () => Navigator.maybePop(context)),
        title: Text(
            sport == LeagueSport.padel && type == 'competition'
                ? 'Nuova competizione'
                : 'Nuova lega',
            style: const TextStyle(
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
            if (sport != LeagueSport.padel) ...[
              const Text('Sport',
                  style: TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _TypeChip(
                        label: 'Calcio',
                        selected: sport == LeagueSport.football,
                        onTap: () => setState(() {
                              sport = LeagueSport.football;
                              if (kind == 'americano') kind = 'league';
                              format = 5;
                            }))),
                const SizedBox(width: 8),
                Expanded(
                    child: _TypeChip(
                        label: 'Padel',
                        selected: sport == LeagueSport.padel,
                        onTap: () => setState(() {
                              sport = LeagueSport.padel;
                              format = 3;
                            }))),
              ]),
              const SizedBox(height: 20),
            ],
            _LeagueNameField(
                controller: name, padel: sport == LeagueSport.padel),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _TypeChip(
                      label: 'Amatoriale',
                      selected: type == 'amateur',
                      accent: sport == LeagueSport.padel
                          ? HaykoColors.padelAccent
                          : null,
                      onTap: () => setState(() => type = 'amateur'))),
              const SizedBox(width: 8),
              Expanded(
                  child: _TypeChip(
                      label: 'Competizione',
                      selected: type == 'competition',
                      accent: sport == LeagueSport.padel
                          ? HaykoColors.padelAccent
                          : null,
                      onTap: () => setState(() {
                            type = 'competition';
                            if (sport == LeagueSport.padel) {
                              doubleLeg = true;
                              format = 3;
                            }
                          }))),
            ]),
            const SizedBox(height: 12),
            if (type == 'amateur')
              Text(
                  sport == LeagueSport.padel
                      ? 'Partite tra amici, coppie flessibili e statistiche individuali.'
                      : 'Un gruppo di amici: partite, giocatori e statistiche.',
                  style: const TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 16,
                      height: 1.5,
                      color: HaykoColors.mutedText)),
            if (type == 'competition') ...[
              _DropdownField<String>(
                  label: 'Tipologia competizione',
                  value: kind,
                  accent: sport == LeagueSport.padel
                      ? HaykoColors.padelAccent
                      : null,
                  items: [
                    DropdownMenuItem(
                        value: 'league',
                        child: Text(sport == LeagueSport.padel
                            ? 'Campionato a coppie fisse'
                            : 'Campionato')),
                    const DropdownMenuItem(
                        value: 'knockout',
                        child: Text('Torneo a eliminazione')),
                    if (sport == LeagueSport.padel)
                      const DropdownMenuItem(
                          value: 'americano', child: Text('Americano')),
                  ],
                  onChanged: (v) => setState(() => kind = v!)),
              const SizedBox(height: 12),
              if (kind == 'league')
                _DoubleLegField(
                    value: doubleLeg,
                    accent: sport == LeagueSport.padel
                        ? HaykoColors.padelAccent
                        : null,
                    onChanged: (v) => setState(() => doubleLeg = v)),
              if (kind == 'league') const SizedBox(height: 12),
              _DropdownField<int>(
                  label: sport == LeagueSport.padel
                      ? 'Formato partita'
                      : 'Tipologia partita',
                  value: format,
                  accent: sport == LeagueSport.padel
                      ? HaykoColors.padelAccent
                      : null,
                  items: sport == LeagueSport.padel
                      ? const [
                          DropdownMenuItem(
                              value: 3, child: Text('Meglio di 3 set')),
                          DropdownMenuItem(
                              value: 5, child: Text('Meglio di 5 set')),
                        ]
                      : [
                          for (var n = 2; n <= 11; n++)
                            DropdownMenuItem(value: n, child: Text('${n}v$n'))
                        ],
                  onChanged: (v) => setState(() => format = v!)),
              const SizedBox(height: 12),
              Text(
                  sport == LeagueSport.padel
                      ? 'Dopo la creazione aggiungi le coppie e i giocatori nella sezione Coppie.'
                      : 'Dopo la creazione aggiungi le squadre, i giocatori e i numeri di maglia nella sezione Squadre.',
                  style: const TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 14,
                      height: 20 / 14,
                      color: HaykoColors.mutedText)),
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
                child: Text(sport == LeagueSport.padel && type == 'competition'
                    ? kind == 'americano'
                        ? 'Configura Americano'
                        : 'Crea competizione'
                    : 'Crea lega')),
          ],
        ),
      ));
}

class _LeagueNameField extends StatelessWidget {
  const _LeagueNameField({required this.controller, this.padel = false});

  final TextEditingController controller;
  final bool padel;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(
                color: padel
                    ? HaykoColors.padelAccent.withValues(alpha: .55)
                    : HaykoColors.fieldLine),
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
      {required this.label,
      required this.selected,
      required this.onTap,
      this.accent});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? HaykoColors.fieldLine : HaykoColors.fieldBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: selected && accent != null
                    ? accent!
                    : HaykoColors.fieldLine,
                width: selected && accent != null ? 2 : 1)),
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

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged,
      this.accent});

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(
                color: accent?.withValues(alpha: .42) ?? HaykoColors.fieldLine),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'BricolageGrotesque',
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: HaykoColors.mutedText)),
          const SizedBox(height: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.arrow_drop_down, size: 18),
                style: const TextStyle(
                    fontFamily: 'BricolageGrotesque',
                    fontSize: 16,
                    height: 1.5,
                    color: HaykoColors.chalk),
                dropdownColor: HaykoColors.fieldSurface,
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ]),
      );
}

class _DoubleLegField extends StatelessWidget {
  const _DoubleLegField(
      {required this.value, required this.onChanged, this.accent});

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(
                color: accent?.withValues(alpha: .3) ?? Colors.transparent),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Andata e ritorno',
                  style: TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 16,
                      height: 1.5)),
              Text(
                  value
                      ? 'Ogni coppia si incontra due volte'
                      : 'Ogni coppia si incontra una volta',
                  style: const TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                      color: HaykoColors.mutedText)),
            ]),
          ),
          SizedBox(
              width: 32,
              height: 32,
              child: Transform.scale(
                  scale: .72,
                  child: Switch(
                      value: value,
                      activeTrackColor: HaykoColors.chalk,
                      activeThumbColor: HaykoColors.fieldLine,
                      onChanged: onChanged))),
        ]),
      );
}
