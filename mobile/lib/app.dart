import 'package:calcetto_mvp/design_system/hayko_theme.dart';
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/features/account/auth_pages.dart';

import 'package:calcetto_mvp/features/home/home_page.dart';

class CalcettoApp extends StatelessWidget {
  const CalcettoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'HAYKO',
      debugShowCheckedModeBanner: false,
      theme: buildHaykoTheme(),
      home: AccountGate(signedIn: (id) => Home(key: ValueKey(id))));
}
