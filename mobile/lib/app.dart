import 'package:calcetto_mvp/design_system/hayko_theme.dart';
import 'package:calcetto_mvp/design_system/hayko_splash.dart';
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/features/account/auth_pages.dart';

import 'package:calcetto_mvp/features/home/home_page.dart';

class CalcettoApp extends StatelessWidget {
  const CalcettoApp({
    super.key,
    required this.initialization,
    this.minimumSplashDuration = const Duration(milliseconds: 900),
    this.destinationBuilder,
  });

  final Future<void> initialization;
  final Duration minimumSplashDuration;
  final WidgetBuilder? destinationBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'HAYKO',
      debugShowCheckedModeBanner: false,
      theme: buildHaykoTheme(),
      home: _StartupGate(
        initialization: initialization,
        minimumSplashDuration: minimumSplashDuration,
        destinationBuilder: destinationBuilder ??
            (_) => AccountGate(signedIn: (id) => Home(key: ValueKey(id))),
      ));
}

class _StartupGate extends StatefulWidget {
  const _StartupGate({
    required this.initialization,
    required this.minimumSplashDuration,
    required this.destinationBuilder,
  });

  final Future<void> initialization;
  final Duration minimumSplashDuration;
  final WidgetBuilder destinationBuilder;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final Future<void> ready;

  @override
  void initState() {
    super.initState();
    final initialization = widget.initialization.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    ready = Future.wait<void>([
      initialization,
      Future<void>.delayed(widget.minimumSplashDuration),
    ]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: ready,
        builder: (context, state) =>
            state.connectionState == ConnectionState.done
                ? widget.destinationBuilder(context)
                : const HaykoSplash(),
      );
}
