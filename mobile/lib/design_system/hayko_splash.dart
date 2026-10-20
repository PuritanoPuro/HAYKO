import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:calcetto_mvp/design_system/hayko_colors.dart';

/// Splash HAYKO, translated from Figma node 48:204.
class HaykoSplash extends StatelessWidget {
  const HaykoSplash({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: HaykoColors.fieldBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Semantics(
                label: 'HAYKO',
                image: true,
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/brand/hayko_falcon_app_v2.svg',
                        width: 210,
                        height: 94.756,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 252,
                        height: 45.161,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/brand/hayko_wordmark_clean.svg',
                            width: 232.375,
                            height: 45.161,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
