import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/features/account/invite_links.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'dart:async';

import 'package:calcetto_mvp/app.dart';
export 'package:calcetto_mvp/app.dart';
export 'package:calcetto_mvp/features/home/home_page.dart';
export 'package:calcetto_mvp/features/leagues/league_page.dart';
export 'package:calcetto_mvp/features/matches/match_page.dart';

const _splashDuration = Duration(
    milliseconds: int.fromEnvironment('HAYKO_SPLASH_MS', defaultValue: 900));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const ['Bricolage Grotesque'],
        await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final initialization = _initializeApplication();
  runApp(CalcettoApp(
      initialization: initialization, minimumSplashDuration: _splashDuration));
}

Future<void> _initializeApplication() async {
  await Cloud.initialize();
  await InviteLinks.initialize();
}
