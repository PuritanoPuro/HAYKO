import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/shared/customization.dart';

class CompetitionMatchForm extends StatefulWidget {
  final League league;
  final String? initialCompetition;
  final List<String>? initialTeams;
  const CompetitionMatchForm(
      {super.key,
      required this.league,
      this.initialCompetition,
      this.initialTeams});
  @override
  State<CompetitionMatchForm> createState() => _CompetitionMatchFormState();
}

class _CompetitionMatchFormState extends State<CompetitionMatchForm> {
  late final Competition c;
  final ids = <String?>[null, null];
  DateTime date = DateTime.now();
  final venue = TextEditingController();
  String? selectedFixture;
  List<TournamentTie> get fixtures => (c.kind == 'knockout'
          ? tournamentTies(widget.league, c)
          : leagueFixtures(widget.league, c))
      .where((tie) => tie.match == null)
      .toList();
  String fixtureKey(TournamentTie tie) => '${tie.round}:${tie.teams.join("|")}';
  @override
  void initState() {
    super.initState();
    c = widget.league.competitions.firstWhere(
        (c) => c.id == widget.initialCompetition,
        orElse: () => widget.league.competitions.first);
    if (widget.initialTeams != null) {
      ids[0] = widget.initialTeams![0];
      ids[1] = widget.initialTeams![1];
    }
  }

  @override
  void dispose() {
    venue.dispose();
    super.dispose();
  }

  void create() {
    if (ids.any((id) => id == null)) {
      showError(context, 'Seleziona una partita dal calendario.');
      return;
    }
    final teams = ids
        .map((id) => widget.league.presets.firstWhere((p) => p.id == id))
        .toList();
    if (teams.any((p) => p.players.length < c.format)) {
      showError(context,
          'Ogni squadra deve avere almeno ${c.format} giocatori. Completa la rosa nella sezione Squadre.');
      return;
    }
    try {
      final ties = c.kind == 'knockout'
          ? tournamentTies(widget.league, c)
              .where(
                  (tie) => tie.match == null && tie.teams.every(ids.contains))
              .toList()
          : <TournamentTie>[];
      if (c.kind == 'knockout' && ties.isEmpty) {
        throw StateError('Seleziona un incontro disponibile nel tabellone.');
      }
      final m = Match(
          id: newId(),
          format: c.format,
          names: teams.map((p) => p.name).toList(),
          teams: teams.map((p) => [...p.players]).toList(),
          keepers: [KeeperPlan.none(), KeeperPlan.none()],
          competitionRules: true,
          creatorId: widget.league.currentUser,
          competitionId: c.id,
          presetIds: [...ids],
          knockoutRound: c.kind == 'knockout' ? ties.first.round : null,
          teamColors: teams.map((p) => p.color).toList(),
          scheduledAt: date.toUtc().toIso8601String(),
          venue: venue.text.trim());
      validateCompetitionMatch(widget.league, m);
      Navigator.pop(context, m);
    } catch (e) {
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Nuova partita')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text('${c.format}v${c.format}', style: const TextStyle(fontSize: 22)),
        if (widget.initialTeams != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      ids
                          .map((id) => widget.league.presets
                              .firstWhere((p) => p.id == id)
                              .name)
                          .join(' – '),
                      style: const TextStyle(fontSize: 22)))),
        if (widget.initialTeams == null)
          DropdownButton<String>(
              key: const ValueKey('calendar-fixture-select'),
              value: selectedFixture,
              isExpanded: true,
              hint: const Text('Scegli la partita dal calendario'),
              items: fixtures
                  .map((tie) => DropdownMenuItem(
                      value: fixtureKey(tie),
                      child: Text(
                          '${c.kind == 'knockout' ? tournamentRoundName(c, tie.round) : 'Giornata ${tie.round}'} · ${tie.teams.map((id) => widget.league.presets.firstWhere((p) => p.id == id).name).join(' – ')}',
                          maxLines: 2)))
                  .toList(),
              onChanged: (v) => setState(() {
                    selectedFixture = v;
                    final tie =
                        fixtures.firstWhere((tie) => fixtureKey(tie) == v);
                    ids[0] = tie.teams[0];
                    ids[1] = tie.teams[1];
                  })),
        if (widget.initialTeams == null && fixtures.isEmpty)
          const Text('Non ci sono incontri disponibili da programmare.'),
        EventDetailsFields(
            date: date, venue: venue, changed: (v) => setState(() => date = v)),
        const Text(
            'Tutta la rosa sarà disponibile per gol e assist, comprese le riserve.'),
        FilledButton(onPressed: create, child: const Text('Crea partita')),
      ]));
}
