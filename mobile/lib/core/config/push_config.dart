import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class PushConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.example.calcettoMvp');

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get appId =>
      defaultTargetPlatform == TargetPlatform.iOS ? iosAppId : androidAppId;

  static bool get complete =>
      supported &&
      apiKey.isNotEmpty &&
      projectId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      appId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId:
          defaultTargetPlatform == TargetPlatform.iOS ? iosBundleId : null);
}
