import 'dart:async';
import 'dart:convert';

import 'package:calcetto_mvp/core/config/push_config.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> haykoFirebaseBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && PushConfig.complete) {
    await Firebase.initializeApp(options: PushConfig.options);
  }
}

class PushNotifications {
  PushNotifications._();
  static final instance = PushNotifications._();

  bool ready = false;
  StreamSubscription<AuthState>? authSubscription;
  StreamSubscription<String>? registeredSubscription;
  StreamSubscription<String>? unregisteredSubscription;
  StreamSubscription<RemoteMessage>? openedSubscription;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static const _installationIdKey = 'hayko_firebase_installation_id';

  Future<void> initialize() async {
    if (ready || !Cloud.ready || !PushConfig.complete) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: PushConfig.options);
      }
      FirebaseMessaging.onBackgroundMessage(haykoFirebaseBackgroundHandler);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
              alert: false, badge: false, sound: false);
      openedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
      registeredSubscription = FirebaseMessaging.instance.onRegistered.listen(
        _registerInstallation,
        onError: (Object error) =>
            debugPrint('Push registration stream failed: $error'),
      );
      unregisteredSubscription =
          FirebaseMessaging.instance.onUnregistered.listen(
        _removeInstallation,
        onError: (Object error) =>
            debugPrint('Push unregistration stream failed: $error'),
      );
      authSubscription = Cloud.client.auth.onAuthStateChange.listen((state) {
        if (state.session != null) unawaited(registerCurrentDevice());
      });
      ready = true;
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openMessage(initial);
      if (Cloud.client.auth.currentUser != null) {
        unawaited(registerCurrentDevice());
      }
    } catch (error) {
      debugPrint('Push initialization failed: $error');
    }
  }

  Future<void> registerCurrentDevice() async {
    if (!ready || Cloud.client.auth.currentUser == null) return;
    try {
      final settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: false, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (_isIOS) {
        for (var attempt = 0; attempt < 10; attempt++) {
          if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        if (await FirebaseMessaging.instance.getAPNSToken() == null) return;
      }
      await FirebaseMessaging.instance.register();
    } catch (error) {
      debugPrint('Push registration failed: $error');
    }
  }

  Future<void> _registerInstallation(String installationId) async {
    if (Cloud.client.auth.currentUser == null) return;
    try {
      await Cloud.client.rpc('hayko_register_push_device', params: {
        'p_installation_id': installationId,
        'p_platform': _isIOS ? 'ios' : 'android',
      });
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_installationIdKey, installationId);
    } catch (error) {
      debugPrint('Push installation registration failed: $error');
    }
  }

  Future<void> _removeInstallation(String installationId) async {
    try {
      if (Cloud.client.auth.currentUser != null) {
        await Cloud.client.rpc('hayko_unregister_push_device', params: {
          'p_installation_id': installationId,
        });
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_installationIdKey);
    } catch (error) {
      debugPrint('Push installation removal failed: $error');
    }
  }

  void _openMessage(RemoteMessage message) {
    if (message.data.isEmpty) return;
    RotationAlerts.instance.openMatch.value = jsonEncode(message.data);
  }

  Future<void> unregisterCurrentDevice() async {
    if (!ready || Cloud.client.auth.currentUser == null) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      final installationId = preferences.getString(_installationIdKey);
      if (installationId != null) {
        await Cloud.client.rpc('hayko_unregister_push_device', params: {
          'p_installation_id': installationId,
        });
      }
    } catch (error) {
      debugPrint('Push unregister failed: $error');
    }
  }
}
