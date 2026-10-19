import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

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
  TournamentTie? get selectedTie {
    final available = fixtures.where((tie) => tie.teams.every(ids.contains));
    return available.isEmpty ? null : available.first;
  }

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

  String get dateText {
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get timeText =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> chooseDate() async {
    final value = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (value != null && mounted) {
      setState(() => date =
          DateTime(value.year, value.month, value.day, date.hour, date.minute));
    }
  }

  Future<void> chooseTime() async {
    final value = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(date));
    if (value != null && mounted) {
      setState(() => date =
          DateTime(date.year, date.month, date.day, value.hour, value.minute));
    }
  }

  Widget field({
    required String label,
    required String value,
    VoidCallback? onTap,
    TextEditingController? controller,
    Key? fieldKey,
  }) =>
      Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 76,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: HaykoColors.fieldLine),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: HaykoColors.mutedText,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 24,
                  child: controller == null
                      ? Text(value,
                          style: const TextStyle(fontSize: 16, height: 24 / 16))
                      : TextField(
                          key: fieldKey,
                          controller: controller,
                          maxLength: 120,
                          style: const TextStyle(fontSize: 16, height: 24 / 16),
                          decoration: const InputDecoration(
                            counterText: '',
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget matchScore() {
    final teams = ids
        .map((id) => widget.league.presets.firstWhere((team) => team.id == id))
        .toList();
    final tie = selectedTie;
    final details = tie == null
        ? '${c.format}v${c.format}'
        : '${c.kind == 'knockout' ? tournamentRoundName(c, tie.round) : 'Giornata ${tie.round}'} · ${c.format}v${c.format}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          _MatchTeam(team: teams[0]),
          const SizedBox(
              width: 42,
              child: Text('0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w800))),
          const SizedBox(
              width: 12,
              child: Text('–',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 20,
                      height: 26 / 20,
                      fontWeight: FontWeight.w700))),
          const SizedBox(
              width: 42,
              child: Text('0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w800))),
          _MatchTeam(team: teams[1]),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(details,
              style: const TextStyle(
                  color: HaykoColors.mutedText, fontSize: 14, height: 20 / 14)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          toolbarHeight: 64, title: const Text('Partita della competizione')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (widget.initialTeams == null)
          Container(
            height: 76,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: HaykoColors.fieldSurface,
                border: Border.all(color: HaykoColors.fieldLine),
                borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  key: const ValueKey('calendar-fixture-select'),
                  value: selectedFixture,
                  isExpanded: true,
                  hint: const Text('Scegli la partita dal calendario'),
                  dropdownColor: HaykoColors.fieldSurface,
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
            ),
          ),
        if (widget.initialTeams == null) const SizedBox(height: 12),
        if (widget.initialTeams == null && fixtures.isEmpty)
          const Text('Non ci sono incontri disponibili da programmare.'),
        if (ids.every((id) => id != null)) ...[
          matchScore(),
          const SizedBox(height: 12),
        ],
        field(label: 'Data', value: dateText, onTap: chooseDate),
        const SizedBox(height: 12),
        field(label: 'Ora', value: timeText, onTap: chooseTime),
        const SizedBox(height: 12),
        field(
            label: 'Luogo · facoltativo',
            value: '',
            controller: venue,
            fieldKey: const ValueKey('event-venue')),
        const SizedBox(height: 12),
        AccountButton('Crea partita', onPressed: create),
      ]));
}

class _MatchTeam extends StatelessWidget {
  const _MatchTeam({required this.team});
  final TeamPreset team;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(width: 56, height: 6, color: Color(team.color)),
        ]),
      );
}
