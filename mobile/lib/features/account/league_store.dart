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
        final oldRows = [...rows];
        rows = [...rows.where((r) => r['state']['id'] != id), copy];
        operations.add(
            {'id': id, 'revision': row['revision'], 'state': copy['state']});
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
