import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
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
    final l = widget.league, data = stats(widget.league, format);
    final byAppearances = playersByAppearances(l, format);
    final ranked = ranking(l, format, metric);
    return ListView(
        shrinkWrap: widget.embedded,
        primary: widget.embedded ? false : null,
        physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(24),
        children: [
          DropdownButton<int>(
              value: format ?? 0,
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                    value: 0, child: Text('Tutti i formati')),
                for (var n = 2; n <= 11; n++)
                  DropdownMenuItem(value: n, child: Text('$n contro $n'))
              ],
              onChanged: (n) => setState(() => format = n == 0 ? null : n)),
          const Text('Statistiche', style: TextStyle(fontSize: 24)),
          const Text(
              'Ordine per partite giocate, poi vittorie, gol e nome. Solo partite terminate. Scorri lateralmente.'),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  columnSpacing: 20,
                  columns: [
                    for (final c in [
                      'Giocatore',
                      'PG',
                      'V',
                      'S',
                      'GF',
                      'A',
                      'GS'
                    ])
                      DataColumn(label: Text(c), numeric: c != 'Giocatore')
                  ],
                  rows: byAppearances.map((p) {
                    final s = data[p.id]!;
                    return DataRow(cells: [
                      DataCell(Row(children: [
                        CircleAvatar(
                            radius: 7, backgroundColor: Color(p.color)),
                        const SizedBox(width: 6),
                        Text(p.name)
                      ])),
                      for (final n in [
                        s.played,
                        s.wins,
                        s.losses,
                        s.goals,
                        s.assists,
                        s.conceded
                      ])
                        DataCell(Text('$n'))
                    ]);
                  }).toList())),
          const Text(
              'PG partite · V vittorie · S sconfitte · GF gol · A assist · GS subiti. I pareggi contano nelle PG.'),
          const SizedBox(height: 24),
          const Text('Classifiche', style: TextStyle(fontSize: 24)),
          Wrap(spacing: 8, children: [
            for (final e in {
              'goals': 'Gol',
              'assists': 'Assist',
              'contributions': 'Gol + assist',
              'pairs': 'Intesa'
            }.entries)
              ChoiceChip(
                  label: Text(e.value),
                  selected: metric == e.key,
                  onSelected: (_) => setState(() => metric = e.key))
          ]),
          Text(metric == 'pairs'
              ? 'Ordine per gol generati / partite insieme nella stessa squadra.'
              : 'Ordine per media a partita. A parità: totale, poi nome.'),
          if (ranked.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nessuna partita terminata per questo formato.')),
          ...ranked.asMap().entries.map((e) => ListTile(
              leading: Text('${e.key + 1}'),
              title: Text(e.value.label),
              subtitle: Text(
                  '${e.value.total} ${metric == 'assists' ? 'assist' : metric == 'contributions' ? 'gol + assist' : 'gol'} · ${e.value.played} partite${metric == 'pairs' ? ' insieme' : ''}'),
              trailing: Text(e.value.average.toStringAsFixed(2)))),
        ]);
  }
}
