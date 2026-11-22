import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/core/domain/padel_scoring.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_standings_page.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelStatisticsSection extends StatefulWidget {
  const PadelStatisticsSection({
    super.key,
    required this.league,
    this.save,
    this.initialCouplesMode = false,
  });

  final League league;
  final Save? save;
  final bool initialCouplesMode;

  @override
  State<PadelStatisticsSection> createState() => _PadelStatisticsSectionState();
}

class _PadelStatisticsSectionState extends State<PadelStatisticsSection> {
  late bool couplesMode = widget.initialCouplesMode;
  int? bestOfFilter;

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final finishedMatches = league.matches.where((match) =>
        match.status == 'finished' &&
        (bestOfFilter == null || match.padelBestOf == bestOfFilter));
    final rows = _playerStatistics(league, finishedMatches);
    final coupleRows = _coupleStatistics(league, finishedMatches);
    final currentCouple = _currentCoupleStatistics(coupleRows, league.myPlayer);
    final americanos = league.competitions.where((competition) =>
        competition.kind == 'americano' &&
        competition.americanoResults.any((round) =>
            round.isNotEmpty && round.every((result) => result.finished)));

    return ListView(
      key: const ValueKey('padel-player-statistics'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 92),
      children: [
        if (widget.save != null) ...[
          for (final competition in americanos) ...[
            InkWell(
              key: ValueKey('americano-standings-open-${competition.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PadelAmericanoStandingsPage(
                        league: league,
                        competition: competition,
                        save: widget.save!,
                      ),
                    ));
                if (mounted) setState(() {});
              },
              child: Container(
                height: 76,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HaykoColors.fieldSurface,
                  border: Border.all(
                      color: HaykoColors.padelAccent.withValues(alpha: .5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(competition.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          competition.americanoTurnStatus == 'finished'
                              ? 'Classifica finale Americano'
                              : 'Classifica Americano',
                          style: const TextStyle(
                              color: HaykoColors.mutedText, fontSize: 13)),
                    ],
                  )),
                  const Icon(Icons.chevron_right,
                      color: HaykoColors.padelAccent),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
        _FormatField(
          value: bestOfFilter,
          onChanged: (value) => setState(() => bestOfFilter = value),
        ),
        const SizedBox(height: 8),
        _StatisticsModeTabs(
          couplesMode: couplesMode,
          onChanged: (value) => setState(() => couplesMode = value),
        ),
        const SizedBox(height: 8),
        Text(
          couplesMode ? 'Statistiche coppie' : 'Statistiche giocatori',
          style: const TextStyle(
            fontSize: 24,
            height: 30 / 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (couplesMode)
          _PadelCoupleStatisticsTable(rows: coupleRows)
        else
          _PadelStatisticsTable(rows: rows, currentPlayerId: league.myPlayer),
        const SizedBox(height: 8),
        const Text(
          'PG partite · V vittorie · S sconfitte\n'
          'SV set vinti · SP set persi · % percentuale vittorie',
          style: TextStyle(
            color: HaykoColors.mutedText,
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (couplesMode) ...[
          if (currentCouple != null)
            _HeadToHeadSection(
              league: league,
              couple: currentCouple,
              allCouples: coupleRows,
              bestOfFilter: bestOfFilter,
            )
          else
            const _EmptyStatisticsCard(),
        ],
      ],
    );
  }
}

class _FormatField extends StatelessWidget {
  const _FormatField({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Formato partita',
              style: TextStyle(
                color: HaykoColors.mutedText,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
                child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                key: const ValueKey('padel-format-filter'),
                value: value,
                isExpanded: true,
                dropdownColor: HaykoColors.fieldSurface,
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('Tutte le partite')),
                  DropdownMenuItem(value: 3, child: Text('Meglio di 3 set')),
                  DropdownMenuItem(value: 5, child: Text('Meglio di 5 set')),
                ],
                onChanged: onChanged,
              ),
            )),
          ],
        ),
      );
}

class _PadelStatisticsTable extends StatelessWidget {
  const _PadelStatisticsTable({
    required this.rows,
    required this.currentPlayerId,
  });

  final List<_PadelPlayerStatistics> rows;
  final String? currentPlayerId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final widths = _statisticsColumnWidths(constraints.maxWidth);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HaykoColors.fieldSurface,
                border: Border.all(color: HaykoColors.fieldLine),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatisticsRow(
                    widths: widths,
                    header: true,
                    values: const [
                      'Giocatore',
                      'PG',
                      'V',
                      'S',
                      'SV',
                      'SP',
                      '%'
                    ],
                  ),
                  if (rows.isEmpty)
                    const SizedBox(
                      height: 64,
                      child: Center(
                        child: Text(
                          'Nessuna partita terminata.',
                          style: TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final row in rows)
                      _StatisticsRow(
                        widths: widths,
                        indicatorColor: row.player.id == currentPlayerId
                            ? Color(row.player.color)
                            : null,
                        playerId: row.player.id,
                        values: [
                          row.player.name,
                          '${row.played}',
                          '${row.wins}',
                          '${row.losses}',
                          '${row.setWins}',
                          '${row.setLosses}',
                          '${row.winPercentage}%',
                        ],
                      ),
                ],
              ),
            ),
          );
        },
      );
}

List<double> _statisticsColumnWidths(double availableWidth) {
  const otherColumns = <double>[140, 34, 32, 32, 36, 36];
  final percentageWidth = availableWidth < 260 ? availableWidth / 5 : 52.0;
  final otherWidth = otherColumns.fold<double>(0, (sum, width) => sum + width);
  final scale = (availableWidth - percentageWidth) / otherWidth;
  return [for (final width in otherColumns) width * scale, percentageWidth];
}

class _StatisticsRow extends StatelessWidget {
  const _StatisticsRow({
    required this.widths,
    required this.values,
    this.header = false,
    this.indicatorColor,
    this.playerId,
  });

  final List<double> widths;
  final List<String> values;
  final bool header;
  final Color? indicatorColor;
  final String? playerId;

  @override
  Widget build(BuildContext context) => Container(
        key: header
            ? const ValueKey('padel-statistics-header')
            : ValueKey('padel-statistics-row-$playerId'),
        height: 48,
        decoration: BoxDecoration(
          color: header ? HaykoColors.fieldLine : HaykoColors.fieldSurface,
          border: header
              ? null
              : const Border(
                  bottom: BorderSide(
                    color: HaykoColors.fieldBackground,
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            for (var index = 0; index < values.length; index++)
              SizedBox(
                key: index == 6 && !header
                    ? ValueKey('padel-statistics-percentage-$playerId')
                    : null,
                width: widths[index],
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      index == 0
                          ? 12
                          : index == 6
                              ? 2
                              : 4,
                      4,
                      index == 6 ? 2 : 4,
                      4),
                  child: Align(
                    alignment:
                        index == 0 ? Alignment.centerLeft : Alignment.center,
                    child: index == 0 && !header
                        ? Row(
                            children: [
                              if (indicatorColor != null) ...[
                                Container(
                                  key: const ValueKey(
                                      'padel-statistics-current-player'),
                                  width: 4,
                                  height: 20,
                                  color: indicatorColor,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  values[index],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : index == 6
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  values[index],
                                  maxLines: 1,
                                  textAlign: index == 0
                                      ? TextAlign.left
                                      : TextAlign.center,
                                  style: TextStyle(
                                    fontSize: header ? 12 : 14,
                                    height: header ? 16 / 12 : 20 / 14,
                                    fontWeight: header
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              )
                            : Text(
                                values[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: index == 0
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: TextStyle(
                                  fontSize: header ? 12 : 14,
                                  height: header ? 16 / 12 : 20 / 14,
                                  fontWeight: header
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _StatisticsModeTabs extends StatelessWidget {
  const _StatisticsModeTabs({
    required this.couplesMode,
    required this.onChanged,
  });

  final bool couplesMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _chip(
              'Giocatori',
              selected: !couplesMode,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _chip(
              'Coppie',
              selected: couplesMode,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      );

  Widget _chip(String label,
          {required bool selected, required VoidCallback onTap}) =>
      Material(
        color: selected ? HaykoColors.fieldLine : HaykoColors.fieldBackground,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          key: ValueKey('padel-statistics-${label.toLowerCase()}-tab'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
}

class _PadelCoupleStatisticsTable extends StatelessWidget {
  const _PadelCoupleStatisticsTable({required this.rows});

  final List<_PadelCoupleStatistics> rows;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final widths = _statisticsColumnWidths(constraints.maxWidth);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HaykoColors.fieldSurface,
                border: Border.all(color: HaykoColors.fieldLine),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatisticsRow(
                    widths: widths,
                    header: true,
                    values: const ['Coppia', 'PG', 'V', 'S', 'SV', 'SP', '%'],
                  ),
                  if (rows.isEmpty)
                    const SizedBox(
                      height: 64,
                      child: Center(
                        child: Text(
                          'Nessuna partita terminata.',
                          style: TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final row in rows)
                      _StatisticsRow(
                        widths: widths,
                        playerId: row.key,
                        values: [
                          row.name,
                          '${row.played}',
                          '${row.wins}',
                          '${row.losses}',
                          '${row.setWins}',
                          '${row.setLosses}',
                          '${row.winPercentage}%',
                        ],
                      ),
                ],
              ),
            ),
          );
        },
      );
}

class _HeadToHeadSection extends StatelessWidget {
  const _HeadToHeadSection({
    required this.league,
    required this.couple,
    required this.allCouples,
    required this.bestOfFilter,
  });

  final League league;
  final _PadelCoupleStatistics couple;
  final List<_PadelCoupleStatistics> allCouples;
  final int? bestOfFilter;

  @override
  Widget build(BuildContext context) {
    final rows = _headToHead(league, couple, bestOfFilter);
    return Column(
      key: const ValueKey('padel-couple-head-to-head'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Testa a testa · ${couple.name}',
          style: const TextStyle(
            fontSize: 20,
            height: 25 / 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const _EmptyHeadToHeadCard()
        else
          for (var index = 0; index < rows.length; index++) ...[
            _HeadToHeadCard(
              row: rows[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _PadelHeadToHeadPage(
                    league: league,
                    initialCoupleIds: couple.playerIds,
                    initialOpponentIds: rows[index].opponentIds,
                    bestOfFilter: bestOfFilter,
                  ),
                ),
              ),
            ),
            if (index != rows.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _HeadToHeadCard extends StatelessWidget {
  const _HeadToHeadCard({required this.row, required this.onTap});

  final _PadelHeadToHead row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          key: ValueKey('padel-head-to-head-${row.opponentKey}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'vs ${row.opponentName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${row.wins} ${row.wins == 1 ? 'vittoria' : 'vittorie'} · '
                          '${row.losses} ${row.losses == 1 ? 'sconfitta' : 'sconfitte'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'ULTIMA',
                        style: TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.lastScore,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _EmptyHeadToHeadCard extends StatelessWidget {
  const _EmptyHeadToHeadCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Nessun confronto diretto disponibile.',
          style: TextStyle(color: HaykoColors.mutedText),
        ),
      );
}

class _PadelHeadToHeadPage extends StatefulWidget {
  const _PadelHeadToHeadPage({
    required this.league,
    required this.initialCoupleIds,
    required this.initialOpponentIds,
    required this.bestOfFilter,
  });

  final League league;
  final List<String> initialCoupleIds;
  final List<String> initialOpponentIds;
  final int? bestOfFilter;

  @override
  State<_PadelHeadToHeadPage> createState() => _PadelHeadToHeadPageState();
}

class _PadelHeadToHeadPageState extends State<_PadelHeadToHeadPage> {
  late String coupleKey = _coupleKey(widget.initialCoupleIds);
  late String opponentKey = _coupleKey(widget.initialOpponentIds);

  List<_PadelCoupleStatistics> get couples => _coupleStatistics(
      widget.league,
      widget.league.matches.where((match) =>
          match.status == 'finished' &&
          (widget.bestOfFilter == null ||
              match.padelBestOf == widget.bestOfFilter)));

  @override
  Widget build(BuildContext context) {
    final rows = couples;
    final selected = rows.firstWhere(
      (row) => row.key == coupleKey,
      orElse: () => rows.first,
    );
    final availableOpponents = rows
        .where((row) =>
            row.key != selected.key &&
            _matchesBetween(
                    widget.league, selected.key, row.key, widget.bestOfFilter)
                .isNotEmpty)
        .toList();
    if (availableOpponents.isNotEmpty &&
        !availableOpponents.any((row) => row.key == opponentKey)) {
      opponentKey = availableOpponents.first.key;
    }
    final opponent = availableOpponents.isEmpty
        ? null
        : availableOpponents.firstWhere((row) => row.key == opponentKey);
    final history = opponent == null
        ? <Match>[]
        : _matchesBetween(
            widget.league, selected.key, opponent.key, widget.bestOfFilter);
    final wins =
        history.where((match) => _coupleWon(match, selected.key)).length;
    final losses = history.length - wins;
    final percentage =
        history.isEmpty ? 0 : (wins * 100 / history.length).round();
    final latest = history.isEmpty ? null : history.first;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        title: const Text('Testa a testa'),
      ),
      body: ListView(
        key: const ValueKey('padel-head-to-head-page'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          _CoupleDropdown(
            label: 'La tua coppia',
            value: selected.key,
            rows: rows,
            onChanged: (value) {
              if (value == null) return;
              setState(() => coupleKey = value);
            },
          ),
          const SizedBox(height: 8),
          _CoupleDropdown(
            label: 'Coppia avversaria',
            value: opponent?.key,
            rows: availableOpponents,
            onChanged: (value) {
              if (value == null) return;
              setState(() => opponentKey = value);
            },
          ),
          const SizedBox(height: 8),
          const _DetailHeading('Bilancio'),
          const SizedBox(height: 8),
          _BalanceCard(wins: wins, losses: losses, percentage: percentage),
          const SizedBox(height: 8),
          const _DetailHeading('Ultima partita'),
          const SizedBox(height: 8),
          if (latest == null || opponent == null)
            const _EmptyHeadToHeadCard()
          else
            _LatestMatchCard(
              league: widget.league,
              match: latest,
              coupleKey: selected.key,
              opponentKey: opponent.key,
            ),
          const SizedBox(height: 8),
          const _DetailHeading('Storico incontri'),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const _EmptyHeadToHeadCard()
          else
            for (var index = 0; index < history.length; index++) ...[
              _HistoryMatchCard(
                match: history[index],
                coupleKey: selected.key,
              ),
              if (index != history.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _CoupleDropdown extends StatelessWidget {
  const _CoupleDropdown({
    required this.label,
    required this.value,
    required this.rows,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<_PadelCoupleStatistics> rows;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(color: HaykoColors.fieldLine),
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
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  dropdownColor: HaykoColors.fieldSurface,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  hint: const Text('Nessuna coppia disponibile'),
                  items: [
                    for (final row in rows)
                      DropdownMenuItem(value: row.key, child: Text(row.name)),
                  ],
                  onChanged: rows.isEmpty ? null : onChanged,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DetailHeading extends StatelessWidget {
  const _DetailHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 20,
          height: 25 / 20,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.wins,
    required this.losses,
    required this.percentage,
  });

  final int wins;
  final int losses;
  final int percentage;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('padel-head-to-head-balance'),
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
                child: _metric('$wins', 'Vittorie', const Color(0xff7ad685))),
            Expanded(
                child:
                    _metric('$losses', 'Sconfitte', const Color(0xffff8c47))),
            Expanded(
                child: _metric(
                    '$percentage%', 'Vittorie %', const Color(0xff63c7f2))),
          ],
        ),
      );

  Widget _metric(String value, String label, Color color) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(color: HaykoColors.mutedText, fontSize: 11)),
        ],
      );
}

class _LatestMatchCard extends StatelessWidget {
  const _LatestMatchCard({
    required this.league,
    required this.match,
    required this.coupleKey,
    required this.opponentKey,
  });

  final League league;
  final Match match;
  final String coupleKey;
  final String opponentKey;

  @override
  Widget build(BuildContext context) {
    final first = _coupleKey(match.teams[0]) == coupleKey ? 0 : 1;
    final second = 1 - first;
    final sets = match.padelSetScores.length;
    return Container(
      key: const ValueKey('padel-head-to-head-latest'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HaykoColors.fieldSurface,
        border: Border.all(color: HaykoColors.fieldLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              flex: 5,
              child: Text(_matchDate(match),
                  style: const TextStyle(
                      color: HaykoColors.mutedText, fontSize: 11)),
            ),
            for (var set = 0; set < sets; set++)
              Expanded(
                child: Text('${set + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: HaykoColors.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 4),
          _scoreRow(first, sets),
          const SizedBox(height: 4),
          _scoreRow(second, sets),
        ],
      ),
    );
  }

  Widget _scoreRow(int team, int sets) => SizedBox(
        height: 40,
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Row(children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(match.teamColors[team]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _coupleName(league, match.teams[team]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          for (var set = 0; set < sets; set++)
            Expanded(
              child: Text('${match.padelSetScores[set][team]}',
                  key: ValueKey('padel-head-to-head-set-$set-team-$team'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: PadelScoring.setWinner(match, set) != null &&
                              PadelScoring.setWinner(match, set) != team
                          ? HaykoColors.mutedText
                          : HaykoColors.chalk,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      );
}

class _HistoryMatchCard extends StatelessWidget {
  const _HistoryMatchCard({required this.match, required this.coupleKey});

  final Match match;
  final String coupleKey;

  @override
  Widget build(BuildContext context) {
    final team = _coupleKey(match.teams[0]) == coupleKey ? 0 : 1;
    final won = _coupleWon(match, coupleKey);
    final color = won ? const Color(0xff7ad685) : const Color(0xffff8c47);
    final score = match.padelSetScores
        .map((set) => '${set[team]}–${set[1 - team]}')
        .join('  ');
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HaykoColors.fieldSurface,
        border: Border.all(color: color.withValues(alpha: .28)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_matchDate(match),
                  style: const TextStyle(
                      color: HaykoColors.mutedText, fontSize: 12)),
              Text(score,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Text(won ? 'VITTORIA' : 'SCONFITTA',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _EmptyStatisticsCard extends StatelessWidget {
  const _EmptyStatisticsCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Le statistiche appariranno dopo la prima partita terminata.',
          style: TextStyle(color: HaykoColors.mutedText),
        ),
      );
}

class _PadelPlayerStatistics {
  _PadelPlayerStatistics(this.player);

  final Player player;
  int played = 0;
  int wins = 0;
  int losses = 0;
  int setWins = 0;
  int setLosses = 0;

  int get winPercentage => played == 0 ? 0 : (wins * 100 / played).round();
}

List<_PadelPlayerStatistics> _playerStatistics(
    League league, Iterable<Match> matches) {
  final totals = {
    for (final player in league.players)
      player.id: _PadelPlayerStatistics(player),
  };

  for (final match in matches) {
    final setWins = [0, 0];
    for (var i = 0; i < match.padelSetScores.length; i++) {
      final winner = PadelScoring.setWinner(match, i);
      if (winner != null) setWins[winner]++;
    }

    for (var team = 0; team < 2; team++) {
      for (final playerId in match.teams[team]) {
        final row = totals[playerId];
        if (row == null) continue;
        row.played++;
        row.setWins += setWins[team];
        row.setLosses += setWins[1 - team];
        if (setWins[team] > setWins[1 - team]) {
          row.wins++;
        } else if (setWins[team] < setWins[1 - team]) {
          row.losses++;
        }
      }
    }
  }

  return totals.values.where((row) => row.played > 0).toList()
    ..sort((a, b) {
      final wins = b.wins.compareTo(a.wins);
      if (wins != 0) return wins;
      final percentage = b.winPercentage.compareTo(a.winPercentage);
      if (percentage != 0) return percentage;
      final played = b.played.compareTo(a.played);
      if (played != 0) return played;
      return a.player.name.toLowerCase().compareTo(b.player.name.toLowerCase());
    });
}

class _PadelCoupleStatistics {
  _PadelCoupleStatistics(this.playerIds, this.name);

  final List<String> playerIds;
  final String name;
  int played = 0;
  int wins = 0;
  int losses = 0;
  int setWins = 0;
  int setLosses = 0;

  String get key => _coupleKey(playerIds);
  int get winPercentage => played == 0 ? 0 : (wins * 100 / played).round();
}

class _PadelHeadToHead {
  _PadelHeadToHead(this.opponentIds, this.opponentName);

  final List<String> opponentIds;
  final String opponentName;
  String get opponentKey => _coupleKey(opponentIds);
  int wins = 0;
  int losses = 0;
  String lastScore = '—';
  DateTime? lastPlayedAt;
}

List<_PadelCoupleStatistics> _coupleStatistics(
    League league, Iterable<Match> matches) {
  final totals = <String, _PadelCoupleStatistics>{};

  for (final match in matches) {
    if (match.teams.length != 2 ||
        match.teams.any((team) => team.length != 2)) {
      continue;
    }
    final setWins = _matchSetWins(match);
    for (var team = 0; team < 2; team++) {
      final ids = [...match.teams[team]]..sort();
      final key = _coupleKey(ids);
      final row = totals.putIfAbsent(
        key,
        () => _PadelCoupleStatistics(ids, _coupleName(league, ids)),
      );
      row.played++;
      row.setWins += setWins[team];
      row.setLosses += setWins[1 - team];
      if (setWins[team] > setWins[1 - team]) {
        row.wins++;
      } else if (setWins[team] < setWins[1 - team]) {
        row.losses++;
      }
    }
  }

  return totals.values.toList()
    ..sort((a, b) {
      final wins = b.wins.compareTo(a.wins);
      if (wins != 0) return wins;
      final percentage = b.winPercentage.compareTo(a.winPercentage);
      if (percentage != 0) return percentage;
      final played = b.played.compareTo(a.played);
      if (played != 0) return played;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}

_PadelCoupleStatistics? _currentCoupleStatistics(
    List<_PadelCoupleStatistics> rows, String? playerId) {
  if (rows.isEmpty) return null;
  if (playerId == null) return rows.first;
  for (final row in rows) {
    if (row.playerIds.contains(playerId)) return row;
  }
  return rows.first;
}

List<_PadelHeadToHead> _headToHead(
    League league, _PadelCoupleStatistics selected, int? bestOfFilter) {
  final result = <String, _PadelHeadToHead>{};
  for (final match in league.matches.where((match) =>
      match.status == 'finished' &&
      (bestOfFilter == null || match.padelBestOf == bestOfFilter))) {
    if (match.teams.length != 2 ||
        match.teams.any((team) => team.length != 2)) {
      continue;
    }
    final selectedTeam = _coupleKey(match.teams[0]) == selected.key
        ? 0
        : _coupleKey(match.teams[1]) == selected.key
            ? 1
            : -1;
    if (selectedTeam < 0) continue;

    final opponentIds = [...match.teams[1 - selectedTeam]]..sort();
    final opponentKey = _coupleKey(opponentIds);
    final row = result.putIfAbsent(
      opponentKey,
      () => _PadelHeadToHead(opponentIds, _coupleName(league, opponentIds)),
    );
    final setWins = _matchSetWins(match);
    if (setWins[selectedTeam] > setWins[1 - selectedTeam]) {
      row.wins++;
    } else if (setWins[selectedTeam] < setWins[1 - selectedTeam]) {
      row.losses++;
    }
    final playedAt = DateTime.tryParse(match.finishedAt ?? '') ??
        DateTime.tryParse(match.startedAt ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (row.lastPlayedAt == null || playedAt.isAfter(row.lastPlayedAt!)) {
      row.lastPlayedAt = playedAt;
      row.lastScore = match.padelSetScores
          .map((score) => selectedTeam == 0
              ? '${score[0]}–${score[1]}'
              : '${score[1]}–${score[0]}')
          .join('  ');
      if (row.lastScore.isEmpty) row.lastScore = '—';
    }
  }

  final rows = result.values.toList()
    ..sort((a, b) => (b.lastPlayedAt ?? DateTime(0))
        .compareTo(a.lastPlayedAt ?? DateTime(0)));
  return rows;
}

List<int> _matchSetWins(Match match) {
  final setWins = [0, 0];
  for (var i = 0; i < match.padelSetScores.length; i++) {
    final winner = PadelScoring.setWinner(match, i);
    if (winner != null) setWins[winner]++;
  }
  return setWins;
}

String _coupleKey(Iterable<String> ids) {
  final sorted = [...ids]..sort();
  return sorted.join('|');
}

String _coupleName(League league, Iterable<String> ids) =>
    ids.map(league.playerName).join(' / ');

List<Match> _matchesBetween(
    League league, String firstKey, String secondKey, int? bestOfFilter) {
  final matches = league.matches.where((match) {
    if (match.status != 'finished' ||
        (bestOfFilter != null && match.padelBestOf != bestOfFilter) ||
        match.teams.length != 2 ||
        match.teams.any((team) => team.length != 2)) {
      return false;
    }
    final keys = match.teams.map(_coupleKey).toSet();
    final setWins = _matchSetWins(match);
    return keys.contains(firstKey) &&
        keys.contains(secondKey) &&
        setWins[0] != setWins[1];
  }).toList()
    ..sort((a, b) => _matchDateTime(b).compareTo(_matchDateTime(a)));
  return matches;
}

bool _coupleWon(Match match, String coupleKey) {
  final team = _coupleKey(match.teams[0]) == coupleKey ? 0 : 1;
  final setWins = _matchSetWins(match);
  return setWins[team] > setWins[1 - team];
}

DateTime _matchDateTime(Match match) =>
    DateTime.tryParse(match.finishedAt ?? '') ??
    DateTime.tryParse(match.startedAt ?? '') ??
    DateTime.tryParse(match.scheduledAt ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

String _matchDate(Match match) {
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
    'dicembre',
  ];
  final date = _matchDateTime(match).toLocal();
  if (date.millisecondsSinceEpoch == 0) return 'Data non indicata';
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
