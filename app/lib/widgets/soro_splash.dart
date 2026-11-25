import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/soro_theme.dart';

/// Short branded splash: the under-dotted logo and Ìlù fade in on the cream
/// dotted paper, then [onDone] fires. Total time stays under 1.5 seconds.
/// With reduced motion on, a still version is shown (no fade) for a moment.
class SoroSplash extends StatefulWidget {
  const SoroSplash({super.key, required this.onDone});

  final VoidCallback onDone;

  static const Duration fadeIn = Duration(milliseconds: 500);
  static const Duration total = Duration(milliseconds: 1200);
  static const Duration stillTotal = Duration(milliseconds: 800);

  @override
  State<SoroSplash> createState() => _SoroSplashState();
}

class _SoroSplashState extends State<SoroSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: SoroSplash.fadeIn,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _fade.value = 1;
    } else {
      _fade.forward();
    }
    _timer = Timer(still ? SoroSplash.stillTotal : SoroSplash.total, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('soro-splash'),
      backgroundColor: SoroTokens.cream,
      body: SoroDottedPaperBackground(
        showWatermark: false,
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Ìlù the talking drum',
                  image: true,
                  child: SvgPicture.asset(
                    'assets/mascot/soro-ilu-encouraging.svg',
                    height: 120,
                  ),
                ),
                const SizedBox(height: SoroTokens.s20),
                Semantics(
                  label: 'Sọ̀rọ̀',
                  image: true,
                  child: SvgPicture.asset(
                    'assets/brand/soro-logo-colour.svg',
                    height: 64,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
