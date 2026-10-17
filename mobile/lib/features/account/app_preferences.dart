import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  const NotificationPreferences(
      {this.enabled = true, this.sound = true, this.vibration = true});
  final bool enabled, sound, vibration;
  static Future<NotificationPreferences> load() async {
    final p = await SharedPreferences.getInstance();
    return NotificationPreferences(
        enabled: p.getBool('hayko.alerts.enabled') ?? true,
        sound: p.getBool('hayko.alerts.sound') ?? true,
        vibration: p.getBool('hayko.alerts.vibration') ?? true);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    final results = await Future.wait([
      p.setBool('hayko.alerts.enabled', enabled),
      p.setBool('hayko.alerts.sound', sound),
      p.setBool('hayko.alerts.vibration', vibration)
    ]);
    if (results.any((ok) => !ok)) throw StateError('Impostazioni non salvate.');
  }
}
