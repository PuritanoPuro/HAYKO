import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef LeagueRpc = Future<dynamic> Function(
    String name, Map<String, dynamic> params);

/// Un documento locale per account. Le operazioni restano ordinate:
/// avvio, gol e chiusura non vengono accorpati in un'unica transizione.
class LeagueStore extends ChangeNotifier {
  LeagueStore(this.userId, this.rpc);
  final String userId;
  final LeagueRpc rpc;
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> operations = [];
  bool initialized = false, syncing = false;
  String? problem;
  Future<void> serial = Future<void>.value();
  Future<void>? _flushFuture;
  String get key => 'hayko.leagues.$userId';
  int get pending => operations.length;

  Future<void> initialize() async {
    if (initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    if (text != null) {
      final data = jsonDecode(text) as Map<String, dynamic>;
      rows = (data['rows'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      operations = (data['operations'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
    initialized = true;
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
        key, jsonEncode({'rows': rows, 'operations': operations}));
    if (!ok) throw StateError('Salvataggio sul dispositivo non riuscito.');
  }

  Future<void> locked(Future<void> Function() work) {
    final result = serial.then((_) => work());
    serial = result.catchError((Object _) {});
    return result;
  }

  Future<void> queue(Map<String, dynamic> row) => locked(() async {
        await initialize();
        final copy = Map<String, dynamic>.from(jsonDecode(jsonEncode(row)));
        final id = copy['state']['id'];
        final previous = rows.where((r) => r['state']['id'] == id);
        final baseState = previous.isEmpty
            ? null
            : jsonDecode(jsonEncode(previous.first['state']));
        if (baseState is Map) {
          _removeLegacyMatchDefaults(
              copy['state'] as Map<String, dynamic>, baseState);
        }
        final oldRows = [...rows];
        rows = [...rows.where((r) => r['state']['id'] != id), copy];
        operations.add({
          'id': id,
          'revision': row['revision'],
          'state': copy['state'],
          if (baseState != null) 'base_state': baseState,
        });
        try {
          await persist();
        } catch (_) {
          rows = oldRows;
          operations.removeLast();
          rethrow;
        }
        notifyListeners();
      });
  Future<void> flush() {
    final active = _flushFuture;
    if (active != null) return active;
    final future = _performFlush();
    _flushFuture = future;
    return future.whenComplete(() {
      if (identical(_flushFuture, future)) _flushFuture = null;
    });
  }

  Future<void> _performFlush() async {
    syncing = true;
    problem = null;
    notifyListeners();
    try {
      await initialize();
      while (operations.isNotEmpty) {
        final op = operations.first;
        // La rete non occupa il lock del salvataggio locale: si possono
        // registrare altri gol mentre questa richiesta attende la risposta.
        dynamic revision;
        try {
          revision = await rpc('bc_save', {
            'p_id': op['id'],
            'p_revision': op['revision'],
            'p_state': op['state'],
          }).timeout(const Duration(seconds: 8));
        } catch (error) {
          if (_isRevisionConflict(error) && await _rebaseConflict(op)) {
            continue;
          }
          if (error.toString().contains('MATCH_FINISHED') &&
              await _repairLegacyMatchDefaults(op)) {
            continue;
          }
          if (!_isPermissionRejection(error)) rethrow;
          // Un rifiuto esplicito del server non puo riuscire con un nuovo
          // tentativo. Rimuoverlo evita che blocchi per sempre le modifiche
          // valide accodate dopo, incluse quelle di altre leghe.
          await locked(() async {
            if (operations.isEmpty || !identical(operations.first, op)) return;
            operations.removeAt(0);
            await persist();
            notifyListeners();
          });
          problem =
              'Una modifica non consentita è stata annullata. Gli altri dati sono stati sincronizzati.';
          continue;
        }
        await locked(() async {
          final previous = jsonEncode({'rows': rows, 'operations': operations});
          operations.removeAt(0);
          for (final next in operations.where((n) => n['id'] == op['id'])) {
            next['revision'] = revision;
          }
          for (final row in rows.where((r) => r['state']['id'] == op['id'])) {
            row['revision'] = revision;
          }
          try {
            await persist();
          } catch (_) {
            final old = jsonDecode(previous) as Map<String, dynamic>;
            rows = (old['rows'] as List)
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
            operations = (old['operations'] as List)
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
            rethrow;
          }
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('HAYKO_SYNC_ERROR: $e');
      problem = e.toString().contains('REVISION_CONFLICT')
          ? 'La lega è cambiata anche su un altro dispositivo. Le tue modifiche sono conservate: occorre risolvere il conflitto prima di sincronizzarle.'
          : 'Modifiche conservate sul dispositivo. Sincronizzazione da completare.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  bool _isPermissionRejection(Object error) {
    final message = error.toString();
    return message.contains('PRESIDENT_REQUIRED') ||
        message.contains('ADMIN_REQUIRED') ||
        message.contains('ONLY_EVENT_CREATOR') ||
        message.contains('FORBIDDEN');
  }

  bool _isRevisionConflict(Object error) =>
      error.toString().contains('REVISION_CONFLICT');

  /// Vecchie partite Padel non contengono i contatori aggiunti in seguito.
  /// La serializzazione non deve farli apparire come modifiche a partite chiuse.
  static bool _removeLegacyMatchDefaults(
      Map<String, dynamic> state, Map baseState) {
    final oldMatches = {
      for (final old in baseState['matches'] as List? ?? [])
        if (old is Map && old['id'] != null) old['id']: old,
    };
    var changed = false;
    for (final match in state['matches'] as List? ?? []) {
      if (match is! Map || match['status'] != 'finished') continue;
      final old = oldMatches[match['id']];
      if (old is! Map || old['status'] != 'finished') continue;
      if (!old.containsKey('padelPointTotals') &&
          _sameJson(match['padelPointTotals'], [0, 0])) {
        match.remove('padelPointTotals');
        changed = true;
      }
      if (!old.containsKey('padelSetDurationsSeconds') &&
          _sameJson(match['padelSetDurationsSeconds'], [])) {
        match.remove('padelSetDurationsSeconds');
        changed = true;
      }
      for (final key in ['padelSetStartedAt', 'padelFirstServerId']) {
        if (!old.containsKey(key) &&
            match.containsKey(key) &&
            match[key] == null) {
          match.remove(key);
          changed = true;
        }
      }
    }
    return changed;
  }

  Future<bool> _repairLegacyMatchDefaults(
      Map<String, dynamic> operation) async {
    var repaired = false;
    await locked(() async {
      if (operations.isEmpty || !identical(operations.first, operation)) return;
      final base = operation['base_state'];
      if (base is! Map) return;
      repaired = _removeLegacyMatchDefaults(
          operation['state'] as Map<String, dynamic>, base);
      if (!repaired) return;
      for (final row
          in rows.where((r) => r['state']['id'] == operation['id'])) {
        _removeLegacyMatchDefaults(row['state'] as Map<String, dynamic>, base);
      }
      await persist();
      notifyListeners();
    });
    return repaired;
  }

  /// Replays the local changes over the latest server document only when the
  /// two devices changed different top-level areas. A real overlap remains a
  /// conflict instead of silently discarding either version.
  Future<bool> _rebaseConflict(Map<String, dynamic> failed) async {
    final remoteRaw = await rpc('bc_get', {'p_id': failed['id']})
        .timeout(const Duration(seconds: 8));
    final remote = Map<String, dynamic>.from(remoteRaw as Map);
    final remoteState = _copyMap(remote['state']);
    final remoteRevision = remote['revision'] as int;
    var resolved = false;

    await locked(() async {
      if (operations.isEmpty || !identical(operations.first, failed)) return;
      var rebasedState = remoteState;
      final leagueOperations =
          operations.where((op) => op['id'] == failed['id']).toList();
      final updates = <Map<String, dynamic>>[];

      for (final operation in leagueOperations) {
        final baseRaw = operation['base_state'];
        if (baseRaw is! Map) return;
        final merged = _mergeTopLevel(
            _copyMap(baseRaw), _copyMap(operation['state']), rebasedState);
        if (merged == null) return;
        updates.add({
          'operation': operation,
          'base': _copyMap(rebasedState),
          'state': merged,
        });
        rebasedState = merged;
      }

      for (final update in updates) {
        final operation = update['operation'] as Map<String, dynamic>;
        operation['revision'] = remoteRevision;
        operation['base_state'] = update['base'];
        operation['state'] = update['state'];
      }
      for (final row in rows.where((r) => r['state']['id'] == failed['id'])) {
        row['revision'] = remoteRevision;
        row['state'] = _copyMap(rebasedState);
      }
      await persist();
      notifyListeners();
      resolved = true;
    });
    return resolved;
  }

  static Map<String, dynamic> _copyMap(dynamic value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

  static Map<String, dynamic>? _mergeTopLevel(Map<String, dynamic> base,
      Map<String, dynamic> local, Map<String, dynamic> remote) {
    final merged = <String, dynamic>{};
    for (final key in {...base.keys, ...local.keys, ...remote.keys}) {
      final baseHas = base.containsKey(key);
      final localHas = local.containsKey(key);
      final remoteHas = remote.containsKey(key);
      final baseValue = base[key];
      final localValue = local[key];
      final remoteValue = remote[key];
      final localChanged =
          localHas != baseHas || !_sameJson(localValue, baseValue);
      final remoteChanged =
          remoteHas != baseHas || !_sameJson(remoteValue, baseValue);

      if (localChanged &&
          remoteChanged &&
          (localHas != remoteHas || !_sameJson(localValue, remoteValue))) {
        return null;
      }
      if (localChanged) {
        if (localHas) merged[key] = jsonDecode(jsonEncode(localValue));
      } else if (remoteHas) {
        merged[key] = jsonDecode(jsonEncode(remoteValue));
      }
    }
    return merged;
  }

  static bool _sameJson(dynamic a, dynamic b) => jsonEncode(a) == jsonEncode(b);

  Future<List<Map<String, dynamic>>> list() async {
    await initialize();
    await flush();
    try {
      final data = await rpc('bc_list', {}).timeout(const Duration(seconds: 8));
      await locked(() async {
        final previous = rows;
        rows = (data as List).map((r) {
          final remote = Map<String, dynamic>.from(r);
          final saved =
              previous.where((v) => v['state']['id'] == remote['state']['id']);
          if (saved.isEmpty) return remote;
          final local = saved.first;
          if (operations.any((o) => o['id'] == remote['state']['id'])) {
            return {
              ...remote,
              'state': local['state'],
              'revision': local['revision']
            };
          }
          return (local['revision'] as int) > (remote['revision'] as int)
              ? local
              : remote;
        }).toList();
        try {
          await persist();
        } catch (_) {
          rows = previous;
          rethrow;
        }
      });
      if (operations.isEmpty) problem = null;
    } catch (_) {
      problem = 'Stai visualizzando le leghe salvate sul dispositivo.';
      if (rows.isEmpty) rethrow;
    }
    notifyListeners();
    return rows;
  }

  Future<Map<String, dynamic>> get(String id) async {
    await initialize();
    await flush();
    if (operations.any((o) => o['id'] == id)) {
      return rows.firstWhere((r) => r['state']['id'] == id);
    }
    try {
      final row = Map<String, dynamic>.from(await rpc('bc_get', {'p_id': id})
          .timeout(const Duration(seconds: 8)));
      await locked(() async {
        // Non sostituire eventuali modifiche accodate mentre la richiesta era in corso.
        if (operations.any((o) => o['id'] == id)) return;
        final saved = rows.where((r) => r['state']['id'] == id);
        if (saved.isNotEmpty &&
            (saved.first['revision'] as int) > (row['revision'] as int)) {
          return;
        }
        rows = [...rows.where((r) => r['state']['id'] != id), row];
        await persist();
        if (operations.isEmpty) problem = null;
        notifyListeners();
      });
      return rows.firstWhere((r) => r['state']['id'] == id);
    } catch (e) {
      // Un rifiuto esplicito del server non viene mascherato dalla cache.
      if (e.toString().contains('FORBIDDEN') ||
          e.toString().contains('NOT_FOUND')) {
        rethrow;
      }
      problem = 'Stai visualizzando gli ultimi dati salvati sul dispositivo.';
      notifyListeners();
      return rows.firstWhere((r) => r['state']['id'] == id,
          orElse: () => throw e);
    }
  }
}
