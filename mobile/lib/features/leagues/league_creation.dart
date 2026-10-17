import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class LeagueCreation extends StatefulWidget {
  const LeagueCreation({super.key});
  @override
  State<LeagueCreation> createState() => _LeagueCreationState();
}

class _LeagueCreationState extends State<LeagueCreation> {
  String name = '', type = 'amateur', kind = 'league';
  int format = 5;
  bool doubleLeg = false;
  void submit() {
    if (name.trim().isEmpty) {
      showError(context, 'Inserisci il nome della lega.');
      return;
    }
    final l = League(newId(), name.trim(), [], [], type: type);
    if (type == 'competition') {
      l.competitions.add(Competition(newId(), name.trim(), kind, format, [],
          doubleLeg: kind == 'league' && doubleLeg, allowDraft: true));
    }
    Navigator.pop(context, l);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Nuova lega')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        TextFormField(
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Nome lega'),
            onChanged: (v) => name = v),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [
          ButtonSegment(
              value: 'amateur',
              icon: Icon(Icons.groups),
              label: Text('Amatoriale')),
          ButtonSegment(
              value: 'competition',
              icon: Icon(Icons.emoji_events),
              label: Text('Competizione'))
        ], selected: {
          type
        }, onSelectionChanged: (v) => setState(() => type = v.first)),
        const SizedBox(height: 12),
        if (type == 'amateur')
          Text('Un gruppo di amici: partite, giocatori e statistiche.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        if (type == 'competition') ...[
          DropdownButtonFormField<String>(
              initialValue: kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo competizione'),
              items: const [
                DropdownMenuItem(value: 'league', child: Text('Campionato')),
                DropdownMenuItem(
                    value: 'knockout', child: Text('Torneo a eliminazione'))
              ],
              onChanged: (v) => setState(() => kind = v!)),
          const SizedBox(height: 12),
          if (kind == 'league')
            SwitchListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                title: const Text('Andata e ritorno'),
                subtitle: Text(doubleLeg
                    ? 'Ogni coppia si incontra due volte'
                    : 'Solo andata: ogni coppia si incontra una volta'),
                value: doubleLeg,
                onChanged: (v) => setState(() => doubleLeg = v)),
          if (kind == 'league') const SizedBox(height: 12),
          DropdownButtonFormField<int>(
              initialValue: format,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Formato partita'),
              items: [
                for (var n = 2; n <= 11; n++)
                  DropdownMenuItem(value: n, child: Text('${n}v$n'))
              ],
              onChanged: (v) => setState(() => format = v!)),
          const SizedBox(height: 12),
          const Text(
              'Dopo la creazione aggiungi le squadre, i giocatori e i numeri di maglia nella sezione Squadre.'),
        ],
        const SizedBox(height: 12),
        FilledButton(onPressed: submit, child: const Text('Crea lega')),
      ]));
}
