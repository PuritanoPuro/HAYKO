import 'package:calcetto_mvp/features/account/app_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'package:calcetto_mvp/core/domain/domain.dart';

class RotationNotice {
  final DateTime when;
  final String text;
  final bool sound, vibration;
  RotationNotice(this.when, this.text, this.sound, this.vibration);
}

// Tutte le leghe condividono il budget di notifiche iOS; massimo 60 imminenti.
List<RotationNotice> rotationNotices(List<League> leagues, DateTime now) {
  final events = <RotationNotice>[];
  for (final l in leagues.where((l) => l.type != 'competition')) {
    for (final m in l.matches.where(
        (m) => m.status == 'live' && m.startedAt != null && l.canRecord(m))) {
      final start = DateTime.parse(m.startedAt!);
      for (var t = 0; t < 2; t++) {
        final k = m.keepers[t];
        if (k.mode != 'rotation' || (!k.sound && !k.vibration)) continue;
        final next = k.nextChange(start, now);
        for (var i = 0; i < 60; i++) {
          final when = next.add(Duration(minutes: i * k.minutes));
          events.add(RotationNotice(
              when,
              '${l.name} · ${m.names[t]}: ${l.playerName(k.at(start, when))} in porta',
              k.sound,
              k.vibration));
        }
      }
    }
  }
  events.sort((a, b) => a.when.compareTo(b.when));
  final grouped = <RotationNotice>[];
  for (final e in events) {
    if (grouped.isNotEmpty && grouped.last.when == e.when) {
      final old = grouped.removeLast();
      grouped.add(RotationNotice(e.when, '${old.text}\n${e.text}',
          old.sound || e.sound, old.vibration || e.vibration));
    } else {
      grouped.add(e);
    }
  }
  return grouped.take(60).toList();
}

class RotationAlerts {
  RotationAlerts._();
  static final instance = RotationAlerts._();
  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;
  final openMatch = ValueNotifier<String?>(null);
  bool exactAllowed = false;
  String? liveSignature;
  String? signature;
  Future<void> pending = Future<void>.value();
  final sources = <String, League>{};
  String? warning;
  DateTime? coveredUntil;
  String? get scheduleInfo {
    if (coveredUntil == null) return null;
    final time = coveredUntil!.toLocal().toString().substring(11, 16);
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'Su iOS suono e vibrazione seguono le impostazioni del telefono.'
        : exactAllowed
            ? 'Su Android gli avvisi seguono le impostazioni del telefono.'
            : 'Su Android gli avvisi possono arrivare in ritardo se l’accesso a Sveglie e promemoria non è consentito.';
    return 'Avvisi programmati fino alle $time. Riaprendo l’app vengono estesi. $platform';
  }

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  Future<void> initialize() async {
    if (!supported || ready) return;
    data.initializeTimeZones();
    await plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_match'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestSoundPermission: false,
                requestBadgePermission: false)),
        onDidReceiveNotificationResponse: (response) {
      if (response.payload?.isNotEmpty == true) {
        openMatch.value = response.payload;
      }
    });
    ready = true;
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      openMatch.value = launch?.notificationResponse?.payload;
    }
  }

  Future<void> requestPermission({bool rotation = true}) async {
    await initialize();
    signature = null;
    if (!ready) return;
    final ios = plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = ios != null
        ? await ios.requestPermissions(alert: true, sound: true, badge: false)
        : await android?.requestNotificationsPermission();
    if (android != null && rotation && granted != false) {
      exactAllowed = await android.requestExactAlarmsPermission() == true;
    }
    warning = granted == false
        ? 'Notifiche disattivate: il giro continua sullo schermo, ma non riceverai gli avvisi.'
        : null;
  }

  Future<void> sync(List<League> leagues) {
    pending = pending.then((_) => performSync(leagues));
    return pending;
  }

  Future<void> performSync(List<League> leagues) async {
    try {
      await initialize();
      if (!ready) return;
      for (final l in leagues) {
        sources[l.id] = l;
      }
      await syncLiveNotifications();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null && await android.areNotificationsEnabled() == false) {
        warning =
            'Notifiche disattivate: abilita le notifiche dell’app nelle impostazioni Android.';
        signature = null;
        liveSignature = null;
        coveredUntil = null;
        return;
      }
      if (android != null) {
        exactAllowed = await android.canScheduleExactNotifications() == true;
        warning = null;
      }
      final settings = await NotificationPreferences.load();
      final events = settings.enabled
          ? rotationNotices(sources.values.toList(), DateTime.now().toUtc())
              .map((e) => RotationNotice(e.when, e.text,
                  e.sound && settings.sound, e.vibration && settings.vibration))
              .toList()
          : <RotationNotice>[];
      final entries = events
          .map((e) =>
              '${e.when.toIso8601String()}|${e.text}|${e.sound}|${e.vibration}')
          .join('\n');
      final nextSignature = '$entries|$exactAllowed';
      if (signature == nextSignature) return;
      for (final p in await plugin.pendingNotificationRequests()) {
        if (p.id >= 90000 && p.id < 90060) await plugin.cancel(p.id);
      }
      coveredUntil = events.isEmpty ? null : events.last.when;
      for (var i = 0; i < events.length; i++) {
        final e = events[i];
        Future<void> schedule(AndroidScheduleMode mode) => plugin.zonedSchedule(
            90000 + i,
            'Cambio portiere',
            e.text,
            tz.TZDateTime.from(e.when, tz.UTC),
            NotificationDetails(
                android: AndroidNotificationDetails(
                    'keeper_v2_${e.sound}_${e.vibration}', 'Giro del portiere',
                    importance: Importance.high,
                    priority: Priority.high,
                    playSound: e.sound,
                    enableVibration: e.vibration,
                    autoCancel: true,
                    timeoutAfter: 8000),
                iOS: DarwinNotificationDetails(
                    presentAlert: true,
                    presentSound: e.sound || e.vibration,
                    presentBadge: false)),
            androidScheduleMode: mode);
        try {
          await schedule(exactAllowed
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle);
        } on PlatformException catch (e) {
          if (e.code != 'exact_alarms_not_permitted') rethrow;
          exactAllowed = false;
          await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
        }
      }
      signature = nextSignature;
    } catch (e) {
      signature = null;
      coveredUntil = null;
      debugPrint('Notification setup failed: $e');
      warning = 'Avvisi non disponibili. Il turno resta consultabile nell’app.';
    }
  }

  Future<void> testNotification() async {
    await requestPermission(rotation: false);
    if (!ready) return;
    await plugin.show(
        89999,
        'Prova avviso',
        'Se ricevi questo avviso, le notifiche sono abilitate.',
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'keeper_v2_true_true', 'Giro del portiere',
                importance: Importance.high, priority: Priority.high),
            iOS: DarwinNotificationDetails(
                presentAlert: true, presentSound: true)));
  }

  Future<void> syncLiveNotifications() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final live = <String, ({League league, Match match})>{};
    for (final l in sources.values) {
      for (final m in l.matches.where((m) => m.status == 'live')) {
        live['${l.id}|${m.id}'] = (league: l, match: m);
      }
    }
    final next = live.entries
        .map((e) =>
            '${e.key}:${e.value.match.score(0)}:${e.value.match.score(1)}')
        .join('|');
    if (next == liveSignature) return;
    for (final notification in await plugin.getActiveNotifications()) {
      if (notification.id != null &&
          notification.id! >= 91000 &&
          notification.id! < 92000) {
        await plugin.cancel(notification.id!);
      }
    }
    var index = 0;
    for (final row in live.values) {
      if (index >= 1000) break;
      final m = row.match;
      await plugin.show(
          91000 + index,
          '${m.names[0]} ${m.score(0)} – ${m.score(1)} ${m.names[1]}',
          'Partita in corso · Tocca per tornare alla partita',
          NotificationDetails(
              android: AndroidNotificationDetails(
            'live_matches',
            'Partite in corso',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            usesChronometer: m.startedAt != null,
            when: m.startedAt == null
                ? null
                : DateTime.parse(m.startedAt!).millisecondsSinceEpoch,
          )),
          payload: jsonEncode({'league': row.league.id, 'match': m.id}));
      index++;
    }
    liveSignature = next;
  }
}
