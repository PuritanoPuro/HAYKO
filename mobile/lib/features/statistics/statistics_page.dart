import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/presentation.dart';

class StatisticsPage extends StatefulWidget {
  final League league;
  final bool embedded;
  const StatisticsPage(
      {super.key, required this.league, this.embedded = false});
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int? format;
  String metric = 'goals';

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final totals = stats(league, format);
    final players = playersByAppearances(league, format);
    final ranked = ranking(league, format, metric);
    return ListView(
      shrinkWrap: widget.embedded,
      primary: widget.embedded ? false : null,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        _FormatField(
          value: format,
          onChanged: (value) => setState(() => format = value),
        ),
        const SizedBox(height: 8),
        const Text('Statistiche giocatori',
            style: TextStyle(
                fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _StatisticsTable(
          players: players,
          totals: totals,
          currentPlayerId: league.myPlayer,
        ),
        const SizedBox(height: 8),
        const Text(
          'PG partite · V vittorie · S sconfitte\nGF gol · A assist · GS gol subiti',
          style: TextStyle(
              color: HaykoColors.mutedText,
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _MetricPicker(
          selected: metric,
          onChanged: (value) => setState(() => metric = value),
        ),
        const SizedBox(height: 8),
        if (ranked.isEmpty)
          const _EmptyRanking()
        else
          ...ranked.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(
                    bottom: entry.key + 1 == ranked.length ? 0 : 8),
                child: _RankingCard(
                  ranking: entry.value,
                  metric: metric,
                  highlighted: entry.value.playerIds.contains(league.myPlayer),
                ),
              )),
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
            const Text('Tipologia partita',
                style: TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600)),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  key: const ValueKey('statistics-format'),
                  value: value ?? 0,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  borderRadius: BorderRadius.circular(12),
                  style: const TextStyle(
                      color: HaykoColors.chalk,
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 16,
                      height: 24 / 16),
                  items: [
                    const DropdownMenuItem(
                        value: 0, child: Text('Tutti i formati')),
                    for (var n = 2; n <= 11; n++)
                      DropdownMenuItem(value: n, child: Text('$n contro $n')),
                  ],
                  onChanged: (selected) => onChanged(
                      selected == null || selected == 0 ? null : selected),
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatisticsTable extends StatelessWidget {
  const _StatisticsTable({
    required this.players,
    required this.totals,
    required this.currentPlayerId,
  });
  final List<Player> players;
  final Map<String, PlayerStats> totals;
  final String? currentPlayerId;
  static const widths = <double>[122, 36, 34, 34, 40, 36, 40];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columnsWidth =
              widths.fold<double>(0, (sum, width) => sum + width);
          final scale = constraints.maxWidth / columnsWidth;
          final fittedWidths = [
            for (final width in widths) width * scale,
          ];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: HaykoColors.fieldSurface,
                  border: Border.all(color: HaykoColors.fieldLine),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatisticsRow(
                      widths: fittedWidths,
                      header: true,
                      values: const [
                        'Giocatore',
                        'PG',
                        'V',
                        'S',
                        'GF',
                        'A',
                        'GS'
                      ]),
                  for (final player in players)
                    _StatisticsRow(
                      widths: fittedWidths,
                      playerId: player.id,
                      indicatorColor: player.id == currentPlayerId
                          ? Color(player.color)
                          : null,
                      values: [
                        player.name,
                        '${totals[player.id]!.played}',
                        '${totals[player.id]!.wins}',
                        '${totals[player.id]!.losses}',
                        '${totals[player.id]!.goals}',
                        '${totals[player.id]!.assists}',
                        '${totals[player.id]!.conceded}',
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
}

class _StatisticsRow extends StatelessWidget {
  const _StatisticsRow({
    required this.values,
    this.header = false,
    this.indicatorColor,
    this.playerId,
    required this.widths,
  });
  final List<String> values;
  final bool header;
  final Color? indicatorColor;
  final String? playerId;
  final List<double> widths;

  @override
  Widget build(BuildContext context) => Container(
        key: header
            ? const ValueKey('statistics-header')
            : ValueKey('statistics-row-$playerId'),
        height: 48,
        decoration: BoxDecoration(
          color: header ? HaykoColors.fieldLine : HaykoColors.fieldSurface,
          border: const Border(
            bottom: BorderSide(color: HaykoColors.fieldBackground, width: 1),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < values.length; i++)
              SizedBox(
                width: widths[i],
                child: Padding(
                  padding: EdgeInsets.fromLTRB(i == 0 ? 12 : 4, 4, 4, 4),
                  child: Align(
                    alignment: i == 0 ? Alignment.centerLeft : Alignment.center,
                    child: i == 0 && !header
                        ? Row(
                            children: [
                              if (indicatorColor != null) ...[
                                Container(
                                  key: ValueKey('statistics-current-$playerId'),
                                  width: 4,
                                  height: 20,
                                  color: indicatorColor,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(values[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        height: 20 / 14,
                                        fontWeight: FontWeight.w400)),
                              ),
                            ],
                          )
                        : Text(values[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: header ? 12 : 14,
                                height: header ? 16 / 12 : 20 / 14,
                                fontWeight: header
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _MetricPicker extends StatelessWidget {
  const _MetricPicker({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  static const metrics = {
    'goals': 'Gol',
    'assists': 'Assist',
    'contributions': 'Gol + assist',
    'pairs': 'Intesa',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in metrics.entries)
                SizedBox(
                  width: width,
                  height: 44,
                  child: _MetricChip(
                      label: entry.value,
                      selected: selected == entry.key,
                      onTap: () => onChanged(entry.key)),
                ),
            ],
          );
        },
      );
}

class _MetricChip extends StatelessWidget {
  const _MetricChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? HaykoColors.fieldLine : HaykoColors.fieldBackground,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: HaykoColors.fieldLine),
            borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

class _RankingCard extends StatelessWidget {
  const _RankingCard(
      {required this.ranking, required this.metric, required this.highlighted});
  final Ranking ranking;
  final String metric;
  final bool highlighted;

  String get unit => metric == 'assists'
      ? 'assist'
      : metric == 'contributions'
          ? 'gol + assist'
          : 'gol';

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey(
            'ranking-${(ranking.playerIds.toList()..sort()).join('-')}'),
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(
                color:
                    highlighted ? HaykoColors.chalk : HaykoColors.fieldSurface),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(ranking.label,
                      style: const TextStyle(fontSize: 16, height: 24 / 16)),
                  Text(
                    '${ranking.total} $unit · ${ranking.played} partite${metric == 'pairs' ? ' insieme' : ''}',
                    style: const TextStyle(
                        color: HaykoColors.mutedText,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(ranking.average.toStringAsFixed(2).replaceAll('.', ','),
                style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12)),
        child: const Text('Nessuna partita terminata per questo formato.',
            style: TextStyle(color: HaykoColors.mutedText)),
      );
}
