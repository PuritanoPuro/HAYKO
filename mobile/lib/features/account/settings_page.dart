import 'package:flutter/material.dart';
import 'package:calcetto_mvp/features/account/app_preferences.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/account/profile_page.dart';
import 'package:calcetto_mvp/features/account/profile_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      AccountScaffold(title: 'Impostazioni', children: [
        AccountButton('Profilo', outline: true, onPressed: () async {
          try {
            final p = await ProfileService.load();
            if (!context.mounted) return;
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => ProfilePage(initial: p)));
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Profilo non disponibile. Riprova.')));
            }
          }
        }),
        AccountButton('Impostazioni notifiche',
            outline: true,
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsPage()))),
        AccountButton('Privacy',
            outline: true,
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AccountScaffold(
                            title: 'Dati personali',
                            children: [
                              Text(
                                  'Il tuo profilo è visibile soltanto a te. L’email viene usata per l’accesso e il recupero della password.'),
                              Text(
                                  'I membri approvati di una lega possono vedere i giocatori, le partite e le statistiche di quella lega.'),
                              Text(
                                  'Le leghe vengono sincronizzate con il tuo account. Una copia sul dispositivo permette di continuare una partita senza connessione.'),
                            ])))),
        AccountButton('Licenze',
            outline: true,
            onPressed: () =>
                showLicensePage(context: context, applicationName: 'HAYKO')),
        const Text(
            'L’intervallo e l’ordine dei cambi portiere si configurano durante la creazione della partita.',
            style: TextStyle(
                fontSize: 14, height: 20 / 14, color: HaykoColors.mutedText)),
      ]);
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationPreferences? settings;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final s = await NotificationPreferences.load();
      if (mounted) setState(() => settings = s);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Impossibile caricare le impostazioni. Riapri questa schermata.');
      }
    }
  }

  Future<void> update(NotificationPreferences value) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await value.save();
      if (mounted) setState(() => settings = value);
      RotationAlerts.instance.signature = null;
      await RotationAlerts.instance.sync([]);
    } catch (_) {
      if (mounted) setState(() => error = 'Impostazioni non salvate. Riprova.');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return AccountScaffold(title: 'Notifiche', children: [
      if (s == null && error == null) const LinearProgressIndicator(),
      if (s != null) ...[
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avvisi cambio portiere'),
            value: s.enabled,
            onChanged: busy
                ? null
                : (v) => update(NotificationPreferences(
                    enabled: v, sound: s.sound, vibration: s.vibration))),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Suoni'),
            value: s.sound,
            onChanged: busy
                ? null
                : (v) => update(NotificationPreferences(
                    enabled: s.enabled, sound: v, vibration: s.vibration))),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibrazioni'),
            value: s.vibration,
            onChanged: busy
                ? null
                : (v) => update(NotificationPreferences(
                    enabled: s.enabled, sound: s.sound, vibration: v))),
        AccountButton('Consenti notifiche sul telefono',
            outline: true,
            onPressed: busy
                ? null
                : () async {
                    try {
                      await RotationAlerts.instance.requestPermission();
                      await RotationAlerts.instance.sync([]);
                      if (mounted) {
                        setState(() => error = RotationAlerts.instance.warning);
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(() => error =
                            'Impossibile richiedere le notifiche. Controlla le impostazioni del telefono.');
                      }
                    }
                  }),
      ],
      if (error != null) Text(error!),
      const Text(
          'Suoni e vibrazioni dipendono anche dalle impostazioni del telefono. Su iOS non possono essere gestiti separatamente per ogni avviso.'),
    ]);
  }
}

class SyncNotice extends StatelessWidget {
  const SyncNotice({super.key, this.onRetry});
  final Future<void> Function()? onRetry;
  @override
  Widget build(BuildContext context) {
    if (!Cloud.ready || Cloud.client.auth.currentUser == null) {
      return const SizedBox.shrink();
    }
    final store = Cloud.store;
    return AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (store.pending == 0 && store.problem == null) {
            return const SizedBox.shrink();
          }
          return Material(
              color: HaykoColors.fieldSurface,
              child: SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(children: [
                      Expanded(
                          child: Text(
                              store.problem ??
                                  '${store.pending} modifiche da sincronizzare',
                              style: const TextStyle(
                                  fontSize: 12, color: HaykoColors.chalk))),
                      TextButton(
                          onPressed: store.syncing
                              ? null
                              : () async {
                                  if (onRetry != null) {
                                    await onRetry!();
                                  } else {
                                    await store.flush();
                                  }
                                },
                          child: Text(store.syncing ? 'Invio…' : 'Riprova')),
                    ])),
              ));
        });
  }
}
