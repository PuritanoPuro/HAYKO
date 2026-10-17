import 'package:calcetto_mvp/core/domain/domain.dart';

class TeamPreset {
  final String id;
  String name;
  int color;
  bool archived;
  final List<String> players;
  final Map<String, int> numbers;
  TeamPreset(this.id, this.name, this.players,
      {this.color = 0xff8ebcff,
      this.archived = false,
      Map<String, int>? numbers})
      : numbers = numbers ?? {};
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'players': players,
        'color': color,
        'numbers': numbers,
        'archived': archived
      };
  factory TeamPreset.fromJson(Map<String, dynamic> j) =>
      TeamPreset(j['id'], j['name'], List<String>.from(j['players']),
          color: j['color'] ?? 0xff8ebcff,
          numbers: Map<String, int>.from(j['numbers'] ?? {}),
          archived: j['archived'] ?? false);
}

class Competition {
  final String id, name, kind;
  final int format;
  final List<String> teamIds;
  final bool doubleLeg;
  Competition(this.id, this.name, this.kind, this.format, this.teamIds,
      {this.doubleLeg = false, bool allowDraft = false}) {
    if (name.trim().isEmpty ||
        !['league', 'knockout'].contains(kind) ||
        format < 2 ||
        format > 11 ||
        (!allowDraft && teamIds.length < 2) ||
        teamIds.toSet().length != teamIds.length ||
        (!allowDraft &&
            kind == 'knockout' &&
            ![2, 4, 8, 16].contains(teamIds.length))) {
      throw ArgumentError(
          'Servono almeno due squadre; per eliminazione 2, 4, 8 o 16.');
    }
  }
  bool get ready => kind == 'knockout'
      ? [2, 4, 8, 16].contains(teamIds.length)
      : teamIds.length >= 2;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'format': format,
        'teamIds': teamIds,
        'doubleLeg': doubleLeg
      };
  factory Competition.fromJson(Map<String, dynamic> j) => Competition(j['id'],
      j['name'], j['kind'], j['format'], List<String>.from(j['teamIds']),
      doubleLeg: j['doubleLeg'] ?? false, allowDraft: true);
}

class TournamentTie {
  final int round;
  final List<String> teams;
  final Match? match;
  TournamentTie(this.round, this.teams, this.match);
  String? get winner =>
      match?.status == 'finished' ? match!.qualifiedTeamId : null;
}

List<TournamentTie> tournamentTies(League l, Competition c) {
  if (!c.ready) return [];
  final result = <TournamentTie>[];
  var current = [...c.teamIds], round = 1;
  while (current.length >= 2) {
    final winners = <String>[];
    for (var i = 0; i < current.length; i += 2) {
      final pair = [current[i], current[i + 1]];
      final matches = l.matches
          .where((m) =>
              m.competitionId == c.id &&
              m.knockoutRound == round &&
              m.presetIds.contains(pair[0]) &&
              m.presetIds.contains(pair[1]))
          .toList();
      final tie =
          TournamentTie(round, pair, matches.isEmpty ? null : matches.first);
      result.add(tie);
      if (tie.winner != null) winners.add(tie.winner!);
    }
    if (winners.length != current.length ~/ 2) break;
    current = winners;
    round++;
  }
  return result;
}

void validateCompetitionMatch(League l, Match m) {
  if (m.competitionId == null) return;
  final c = l.competitions.firstWhere((c) => c.id == m.competitionId);
  if (!c.ready) {
    throw StateError(
        'Completa le squadre partecipanti prima di creare partite.');
  }
  if (m.format != c.format ||
      m.presetIds.any((id) => id == null || !c.teamIds.contains(id)) ||
      m.presetIds[0] == m.presetIds[1]) {
    throw ArgumentError(
        'Seleziona due preset distinti iscritti alla competizione.');
  }
  if (c.kind == 'knockout') {
    final valid = tournamentTies(l, c).any((tie) =>
        tie.round == m.knockoutRound &&
        tie.match == null &&
        tie.teams.every(m.presetIds.contains));
    if (!valid) {
      throw StateError('Questo incontro non è disponibile nel turno attuale.');
    }
  } else if (l.type == 'competition') {
    final valid = leagueFixtures(l, c).any((tie) =>
        tie.match == null &&
        (c.doubleLeg
            ? tie.teams[0] == m.presetIds[0] && tie.teams[1] == m.presetIds[1]
            : tie.teams.every(m.presetIds.contains)));
    if (!valid) {
      throw StateError('Questa partita è già programmata nel calendario.');
    }
  }
}

class TeamStats {
  final TeamPreset team;
  int played = 0, wins = 0, draws = 0, losses = 0, goals = 0, conceded = 0;
  TeamStats(this.team);
  int get points => wins * 3 + draws;
  int get difference => goals - conceded;
}

List<TeamStats> teamStandings(League l, Competition c) {
  final rows = {
    for (final id in c.teamIds)
      id: TeamStats(l.presets.firstWhere((p) => p.id == id))
  };
  for (final m in l.matches
      .where((m) => m.status == 'finished' && m.competitionId == c.id)) {
    for (var t = 0; t < 2; t++) {
      final s = rows[m.presetIds[t]]!;
      s.played++;
      s.goals += m.score(t);
      s.conceded += m.score(1 - t);
      if (m.score(t) > m.score(1 - t)) {
        s.wins++;
      } else if (m.score(t) == m.score(1 - t)) {
        s.draws++;
      } else {
        s.losses++;
      }
    }
  }
  final sorted = rows.values.toList()
    ..sort((a, b) {
      if (c.kind == 'knockout') {
        const statusOrder = {'Vincitrice': 0, 'In gara': 1, 'Eliminata': 2};
        final status = statusOrder[tournamentStatus(l, c, a.team.id)]!
            .compareTo(statusOrder[tournamentStatus(l, c, b.team.id)]!);
        if (status != 0) return status;
      }
      final comparisons = c.kind == 'league'
          ? [
              b.points.compareTo(a.points),
              b.difference.compareTo(a.difference),
              b.goals.compareTo(a.goals)
            ]
          : [
              b.played.compareTo(a.played),
              b.goals.compareTo(a.goals),
              b.difference.compareTo(a.difference)
            ];
      for (final value in comparisons) {
        if (value != 0) return value;
      }
      return a.team.name.toLowerCase().compareTo(b.team.name.toLowerCase());
    });
  return sorted;
}

String tournamentStatus(League l, Competition c, String teamId) {
  final ties = tournamentTies(l, c);
  if (ties.any((t) =>
      t.winner != null && t.teams.contains(teamId) && t.winner != teamId)) {
    return 'Eliminata';
  }
  if (ties.isNotEmpty &&
      ties.last.winner == teamId &&
      ties.last.round == _roundCount(c.teamIds.length)) {
    return 'Vincitrice';
  }
  return 'In gara';
}

int _roundCount(int n) {
  var count = 0;
  while (n > 1) {
    n ~/= 2;
    count++;
  }
  return count;
}

// Metodo circolare: ogni squadra incontra ogni altra una volta; con un numero
// dispari di squadre, una riposa in ciascuna giornata.
List<TournamentTie> leagueFixtures(League l, Competition c) {
  if (!c.ready) return [];
  final wheel = <String?>[...c.teamIds];
  if (wheel.length.isOdd) wheel.add(null);
  final result = <TournamentTie>[];
  for (var round = 1; round < wheel.length; round++) {
    for (var i = 0; i < wheel.length ~/ 2; i++) {
      final a = wheel[i], b = wheel[wheel.length - 1 - i];
      if (a == null || b == null) continue;
      final games = l.matches.where((m) =>
          m.competitionId == c.id &&
          (c.doubleLeg
              ? m.presetIds[0] == a && m.presetIds[1] == b
              : m.presetIds.contains(a) && m.presetIds.contains(b)));
      result.add(
          TournamentTie(round, [a, b], games.isEmpty ? null : games.first));
    }
    wheel.insert(1, wheel.removeLast());
  }
  if (c.doubleLeg) {
    final first = [...result];
    for (final tie in first) {
      final a = tie.teams[1], b = tie.teams[0];
      final games = l.matches.where((m) =>
          m.competitionId == c.id &&
          m.presetIds[0] == a &&
          m.presetIds[1] == b);
      result.add(TournamentTie(tie.round + wheel.length - 1, [a, b],
          games.isEmpty ? null : games.first));
    }
  }
  return result;
}

String competitionLabel(League l, Match m) {
  final options = l.competitions.where((c) => c.id == m.competitionId);
  if (options.isEmpty) return '';
  final c = options.first;
  if (c.kind == 'knockout') return '${c.name} · Turno ${m.knockoutRound ?? 1}';
  final ties = leagueFixtures(l, c).where((t) => c.doubleLeg
      ? t.teams[0] == m.presetIds[0] && t.teams[1] == m.presetIds[1]
      : t.teams.every(m.presetIds.contains));
  return '${c.name}${ties.isEmpty ? '' : ' · Giornata ${ties.first.round}'}';
}

League competitionPlayers(League l, Competition c) {
  final matches = l.matches.where((m) => m.competitionId == c.id).toList();
  final ids = <String>{
    ...l.presets
        .where((p) => c.teamIds.contains(p.id))
        .expand((p) => p.players),
    ...matches.expand((m) => m.teams.expand((t) => t)),
  };
  return League(l.id, l.name,
      l.players.where((p) => ids.contains(p.id)).toList(), matches);
}

String tournamentRoundName(Competition c, int round) {
  final remaining = c.teamIds.length >> (round - 1);
  return {
        2: 'Finale',
        4: 'Semifinali',
        8: 'Quarti di finale',
        16: 'Ottavi di finale',
        32: 'Sedicesimi di finale'
      }[remaining] ??
      'Turno $round';
}

String competitionRoundLabel(League l, Match m) {
  final options = l.competitions.where((c) => c.id == m.competitionId);
  if (options.isEmpty) return '';
  final c = options.first;
  if (c.kind == 'knockout') return tournamentRoundName(c, m.knockoutRound ?? 1);
  final ties = leagueFixtures(l, c).where((t) => c.doubleLeg
      ? t.teams[0] == m.presetIds[0] && t.teams[1] == m.presetIds[1]
      : t.teams.every(m.presetIds.contains));
  return ties.isEmpty ? '' : 'Giornata ${ties.first.round}';
}

String competitionPlayerLabel(League l, Match m, int side, String id) {
  final teams = l.presets.where((p) => p.id == m.presetIds[side]);
  final number = teams.isEmpty ? null : teams.first.numbers[id];
  return '${number == null ? '' : '#$number · '}${l.playerName(id)}';
}

List<String> competitionWinners(League l, Competition c) {
  if (!c.ready) return [];
  if (c.kind == 'knockout') {
    final ties = tournamentTies(l, c);
    final finalTies =
        ties.where((t) => t.round == _roundCount(c.teamIds.length));
    return finalTies.isEmpty || finalTies.first.winner == null
        ? []
        : [finalTies.first.winner!];
  }
  final fixtures = leagueFixtures(l, c);
  if (fixtures.isEmpty || fixtures.any((t) => t.match?.status != 'finished')) {
    return [];
  }
  final rows = teamStandings(l, c), first = rows.first;
  return rows
      .where((r) =>
          r.points == first.points &&
          r.difference == first.difference &&
          r.goals == first.goals)
      .map((r) => r.team.id)
      .toList();
}
