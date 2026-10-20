import 'dart:math';
import 'package:calcetto_mvp/core/domain/competition_domain.dart';
export 'package:calcetto_mvp/core/domain/competition_domain.dart';

String newId() {
  final r = Random.secure();
  return List.generate(
      16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class Player {
  final String id;
  String name;
  int color;
  Player(this.id, this.name, {this.color = 0xffbbf568});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
  factory Player.fromJson(Map<String, dynamic> j) =>
      Player(j['id'], j['name'], color: j['color'] ?? 0xffbbf568);
}

class Goal {
  final String id;
  final int team;
  final String? scorer, assist, keeper;
  final bool ownGoal;
  final String time;
  bool voided;
  Goal(
      {required this.id,
      required this.team,
      this.scorer,
      this.assist,
      this.keeper,
      this.ownGoal = false,
      required this.time,
      this.voided = false});
  Map<String, dynamic> toJson() => {
        'id': id,
        'team': team,
        'scorer': scorer,
        'assist': assist,
        'keeper': keeper,
        'ownGoal': ownGoal,
        'time': time,
        'voided': voided
      };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
      id: j['id'],
      team: j['team'],
      scorer: j['scorer'],
      assist: j['assist'],
      keeper: j['keeper'],
      ownGoal: j['ownGoal'],
      time: j['time'],
      voided: j['voided']);
}

class Match {
  final String id;
  final int format;
  final List<String> names;
  final List<List<String>> teams;
  String status;
  String? startedAt, finishedAt;
  final List<Goal> goals;
  final List<KeeperPlan> keepers;
  String? creatorId;
  String? scheduledAt;
  String venue;
  final List<int> teamColors;
  final List<String?> presetIds;
  final String? competitionId;
  final int? knockoutRound;
  String? qualifiedTeamId;
  final bool competitionRules;
  Match(
      {required this.id,
      required this.format,
      required this.names,
      required this.teams,
      this.status = 'scheduled',
      this.startedAt,
      this.finishedAt,
      List<Goal>? goals,
      List<KeeperPlan>? keepers,
      this.creatorId,
      this.scheduledAt,
      this.venue = '',
      List<int>? teamColors,
      List<String?>? presetIds,
      this.competitionId,
      this.knockoutRound,
      this.qualifiedTeamId,
      this.competitionRules = false})
      : goals = goals ?? [],
        keepers = keepers ?? [KeeperPlan.manual(), KeeperPlan.manual()],
        teamColors = teamColors ?? [0xff8ebcff, 0xffffab64],
        presetIds = presetIds ?? [null, null] {
    if (format < 2 ||
        format > 11 ||
        teams.length != 2 ||
        names.length != 2 ||
        teams.any((t) => competitionRules
            ? t.length < format || t.length > 60
            : t.length != format) ||
        teams.expand((t) => t).toSet().length !=
            teams.expand((t) => t).length ||
        names.any((n) => n.trim().isEmpty)) {
      throw ArgumentError(
          'Servono due squadre complete con giocatori distinti e nomi validi.');
    }
    if (this.teamColors.length != 2 || this.presetIds.length != 2) {
      throw ArgumentError('Dati squadra non validi.');
    }
    if (this.keepers.length != 2) {
      throw ArgumentError('Configurazione portieri non valida.');
    }
    if (competitionRules) {
      this.keepers
        ..clear()
        ..addAll([KeeperPlan.none(), KeeperPlan.none()]);
    } else {
      for (var t = 0; t < 2; t++) {
        this.keepers[t].validate(teams[t]);
      }
    }
  }
  int score(int team) => goals.where((g) => !g.voided && g.team == team).length;
  void start() {
    if (status != 'scheduled') throw StateError('Partita già iniziata.');
    status = 'live';
    startedAt = DateTime.now().toUtc().toIso8601String();
  }

  void finish({String? winner}) {
    if (status != 'live') throw StateError('Partita non in corso.');
    if (knockoutRound != null) {
      final chosen = score(0) == score(1)
          ? winner
          : presetIds[score(0) > score(1) ? 0 : 1];
      if (chosen == null || !presetIds.contains(chosen)) {
        throw StateError('Scegli la squadra che passa il turno.');
      }
      qualifiedTeamId = chosen;
    }
    status = 'finished';
    finishedAt = DateTime.now().toUtc().toIso8601String();
  }

  void editDetails(DateTime date, String location) {
    if (status != 'scheduled') {
      throw StateError(
          'I dettagli sono modificabili soltanto prima dell’avvio.');
    }
    if (location.trim().length > 120) {
      throw ArgumentError('Il luogo può contenere al massimo 120 caratteri.');
    }
    scheduledAt = date.toUtc().toIso8601String();
    venue = location.trim();
  }

  void add(Goal g) {
    // Idempotenza: ritrasmissione identica, riuso dell'ID con dati diversi rifiutato.
    final previous = goals.where((x) => x.id == g.id);
    if (previous.isNotEmpty) {
      final old = previous.first;
      if (old.team != g.team ||
          old.scorer != g.scorer ||
          old.assist != g.assist ||
          old.keeper != g.keeper ||
          old.ownGoal != g.ownGoal ||
          old.time != g.time) {
        throw StateError('ID già usato per un altro gol.');
      }
      return;
    }
    if (status != 'live') {
      throw StateError('Avvia la partita prima di registrare.');
    }
    if (g.team != 0 && g.team != 1) throw ArgumentError('Squadra non valida.');
    final attack = teams[g.team], defence = teams[1 - g.team];
    if (g.scorer != null &&
        !(g.ownGoal ? defence : attack).contains(g.scorer)) {
      throw ArgumentError('Marcatore nella squadra sbagliata.');
    }
    if (g.assist != null &&
        (g.ownGoal || !attack.contains(g.assist) || g.assist == g.scorer)) {
      throw ArgumentError('Assist non valido.');
    }
    if (competitionRules && g.keeper != null) {
      throw ArgumentError('Nelle competizioni non si registra il portiere.');
    }
    if (g.keeper != null && !defence.contains(g.keeper)) {
      throw ArgumentError('Portiere non valido.');
    }
    if (!competitionRules &&
        keepers[1 - g.team].mode == 'fixed' &&
        g.keeper != keepers[1 - g.team].fixed) {
      throw ArgumentError('Il portiere deve corrispondere a quello fisso.');
    }
    if (g.voided) throw ArgumentError('Un nuovo gol non può essere annullato.');
    goals.add(g);
  }

  void undo(String id) {
    if (status != 'live') throw StateError('Partita non in corso.');
    goals.firstWhere((g) => g.id == id).voided = true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'format': format,
        'names': names,
        'teams': teams,
        'status': status,
        'startedAt': startedAt,
        'finishedAt': finishedAt,
        'goals': goals.map((g) => g.toJson()).toList(),
        'creatorId': creatorId,
        'keepers': keepers.map((k) => k.toJson()).toList(),
        'scheduledAt': scheduledAt,
        'venue': venue,
        'teamColors': teamColors,
        'presetIds': presetIds,
        'competitionId': competitionId,
        'knockoutRound': knockoutRound,
        'qualifiedTeamId': qualifiedTeamId,
        'competitionRules': competitionRules
      };
  factory Match.fromJson(Map<String, dynamic> j) => Match(
      id: j['id'],
      format: j['format'],
      names: List<String>.from(j['names']),
      teams: (j['teams'] as List).map((t) => List<String>.from(t)).toList(),
      status: j['status'],
      startedAt: j['startedAt'],
      finishedAt: j['finishedAt'],
      goals: (j['goals'] as List)
          .map((g) => Goal.fromJson(Map<String, dynamic>.from(g)))
          .toList(),
      creatorId: j['creatorId'],
      scheduledAt: j['scheduledAt'],
      venue: j['venue'] ?? '',
      teamColors:
          j['teamColors'] == null ? null : List<int>.from(j['teamColors']),
      presetIds:
          j['presetIds'] == null ? null : List<String?>.from(j['presetIds']),
      competitionId: j['competitionId'],
      knockoutRound: j['knockoutRound'],
      qualifiedTeamId: j['qualifiedTeamId'],
      competitionRules: j['competitionRules'] ?? false,
      keepers: (j['keepers'] as List?)
          ?.map((k) => KeeperPlan.fromJson(Map<String, dynamic>.from(k)))
          .toList());
}

class KeeperPlan {
  final String mode;
  final String? fixed;
  final List<String> order;
  final int minutes;
  final bool sound, vibration;
  KeeperPlan(
      {required this.mode,
      this.fixed,
      List<String>? order,
      this.minutes = 5,
      this.sound = true,
      this.vibration = true})
      : order = order ?? [];
  factory KeeperPlan.manual() => KeeperPlan(mode: 'manual');
  factory KeeperPlan.none() =>
      KeeperPlan(mode: 'none', sound: false, vibration: false);
  void validate(List<String> team) {
    if (!['manual', 'fixed', 'rotation', 'none'].contains(mode)) {
      throw ArgumentError('Tipo portiere non valido.');
    }
    if (mode == 'fixed' && !team.contains(fixed)) {
      throw ArgumentError('Scegli il portiere fisso.');
    }
    if (mode == 'rotation' &&
        (minutes < 1 ||
            minutes > 60 ||
            order.length != team.length ||
            order.toSet().length != team.length ||
            order.any((p) => !team.contains(p)))) {
      throw ArgumentError(
          'Il giro deve includere tutti i giocatori una sola volta e durare 1–60 minuti.');
    }
  }

  String? at(DateTime start, DateTime now) {
    if (mode == 'fixed') return fixed;
    if (mode != 'rotation' || order.isEmpty) return null;
    final seconds = now.difference(start).inSeconds;
    final turn = (seconds < 0 ? 0 : seconds) ~/ (minutes * 60);
    return order[turn % order.length];
  }

  DateTime nextChange(DateTime start, DateTime now) {
    final seconds = now.difference(start).inSeconds;
    final turn = (seconds < 0 ? 0 : seconds) ~/ (minutes * 60);
    return start.add(Duration(minutes: (turn + 1) * minutes));
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'fixed': fixed,
        'order': order,
        'minutes': minutes,
        'sound': sound,
        'vibration': vibration
      };
  factory KeeperPlan.fromJson(Map<String, dynamic> j) => KeeperPlan(
      mode: j['mode'],
      fixed: j['fixed'],
      order: List<String>.from(j['order'] ?? []),
      minutes: j['minutes'] ?? 5,
      sound: j['sound'] ?? true,
      vibration: j['vibration'] ?? true);
}

List<String> goalSteps(Match m, int beneficiary, bool own) => [
      'team',
      'scorer',
      if (!own) 'assist',
      if (!m.competitionRules &&
          !['fixed', 'none'].contains(m.keepers[1 - beneficiary].mode))
        'keeper',
      'review'
    ];

class League {
  final String id;
  String name;
  int primaryColor, secondaryColor;
  String type;
  final List<TeamPreset> presets;
  final List<Competition> competitions;
  final List<Player> players;
  final List<Match> matches;
  bool shared = false;
  int revision = 0;
  String? currentUser, myRole, myPlayer;
  Map<String, String> roles = {};
  League(this.id, this.name, this.players, this.matches,
      {this.primaryColor = 0xffbbf568,
      this.secondaryColor = 0xff8ebcff,
      this.type = 'amateur',
      List<TeamPreset>? presets,
      List<Competition>? competitions})
      : presets = presets ?? [],
        competitions = competitions ?? [];
  bool get manage => !shared || myRole == 'president' || myRole == 'admin';
  bool get president => !shared || myRole == 'president';
  bool canRecord(Match m) =>
      !shared || (manage && currentUser != null && m.creatorId == currentUser);
  String playerName(String? id) =>
      id == null ? 'Non indicato' : players.firstWhere((p) => p.id == id).name;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'type': type,
        'presets': presets.map((p) => p.toJson()).toList(),
        'competitions': competitions.map((c) => c.toJson()).toList(),
        'players': players.map((p) => p.toJson()).toList(),
        'matches': matches.map((m) => m.toJson()).toList()
      };
  factory League.fromJson(Map<String, dynamic> j) => League(
      j['id'],
      j['name'],
      (j['players'] as List)
          .map((p) => Player.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      (j['matches'] as List).map((m) {
        final row = Map<String, dynamic>.from(m);
        if ((j['type'] ??
                ((j['competitions'] as List? ?? []).isEmpty
                    ? 'amateur'
                    : 'competition')) ==
            'competition') {
          row['competitionRules'] = true;
        }
        return Match.fromJson(row);
      }).toList(),
      primaryColor: j['primaryColor'] ?? 0xffbbf568,
      secondaryColor: j['secondaryColor'] ?? 0xff8ebcff,
      type: j['type'] ??
          ((j['competitions'] as List? ?? []).isEmpty
              ? 'amateur'
              : 'competition'),
      presets: (j['presets'] as List? ?? [])
          .map((p) => TeamPreset.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      competitions: (j['competitions'] as List? ?? [])
          .map((c) => Competition.fromJson(Map<String, dynamic>.from(c)))
          .toList());
}

class PlayerStats {
  int goals = 0,
      assists = 0,
      conceded = 0,
      ownGoals = 0,
      played = 0,
      wins = 0,
      draws = 0;
  int get losses => played - wins - draws;
}

class Ranking {
  final String label;
  final int total, played;
  final Set<String> playerIds;
  Ranking(this.label, this.total, this.played,
      {Iterable<String> playerIds = const []})
      : playerIds = Set.unmodifiable(playerIds);
  double get average => played == 0 ? 0 : total / played;
}

List<Ranking> ranking(League l, int? format, String metric) {
  final rows = <Ranking>[];
  if (metric == 'pairs') {
    final totals = pairs(l, format);
    final appearances = <String, int>{};
    for (final m in l.matches.where((m) =>
        m.status == 'finished' && (format == null || m.format == format))) {
      for (final team in m.teams) {
        for (var a = 0; a < team.length; a++) {
          for (var b = a + 1; b < team.length; b++) {
            final ids = [team[a], team[b]]..sort();
            final key = ids.join('|');
            appearances[key] = (appearances[key] ?? 0) + 1;
          }
        }
      }
    }
    for (final e in appearances.entries) {
      final ids = e.key.split('|');
      rows.add(Ranking(
          ids.map(l.playerName).join(' + '), totals[e.key] ?? 0, e.value,
          playerIds: ids));
    }
  } else {
    final s = stats(l, format);
    for (final p in l.players) {
      final x = s[p.id]!;
      if (x.played > 0) {
        rows.add(Ranking(
            p.name,
            metric == 'goals'
                ? x.goals
                : metric == 'assists'
                    ? x.assists
                    : x.goals + x.assists,
            x.played,
            playerIds: [p.id]));
      }
    }
  }
  rows.sort((a, b) {
    final rate = b.average.compareTo(a.average);
    if (rate != 0) return rate;
    final total = b.total.compareTo(a.total);
    return total != 0
        ? total
        : a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return rows;
}

Map<String, PlayerStats> stats(League league, int? format) {
  final result = {for (final p in league.players) p.id: PlayerStats()};
  for (final m in league.matches.where((m) =>
      m.status == 'finished' && (format == null || m.format == format))) {
    for (var team = 0; team < 2; team++) {
      for (final id in m.teams[team]) {
        final s = result[id]!;
        s.played++;
        if (m.score(team) > m.score(1 - team)) s.wins++;
        if (m.score(team) == m.score(1 - team)) s.draws++;
      }
    }
    for (final g in m.goals.where((g) => !g.voided)) {
      if (g.scorer != null) {
        if (g.ownGoal) {
          result[g.scorer]!.ownGoals++;
        } else {
          result[g.scorer]!.goals++;
        }
      }
      if (g.assist != null) result[g.assist]!.assists++;
      if (g.keeper != null) result[g.keeper]!.conceded++;
    }
  }
  return result;
}

Map<String, int> pairs(League league, int? format) {
  final result = <String, int>{};
  for (final m in league.matches.where((m) =>
      m.status == 'finished' && (format == null || m.format == format))) {
    for (final g in m.goals.where((g) =>
        !g.voided && !g.ownGoal && g.scorer != null && g.assist != null)) {
      final ids = [g.scorer!, g.assist!]..sort();
      final key = ids.join('|');
      result[key] = (result[key] ?? 0) + 1;
    }
  }
  return result;
}
