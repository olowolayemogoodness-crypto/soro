import 'package:flutter/material.dart';

/// Core design system tokens from the Sọ̀rọ̀ design study (`soro-feel` & `soro-ui` §2).
///
/// All text pairings are verified >= 4.5:1 WCAG AA contrast (UI controls >= 3:1):
/// - `ink` (#292927) on `cream` (#F6F1DE): 12.88:1
/// - `ink` (#292927) on `paper` (#FFFFFF): 14.58:1
/// - `ink2` (#565044) on `cream` (#F6F1DE): 7.06:1
/// - `paper` (#FFFFFF) on `crimson` (#C31E49): 5.83:1
/// - `crimson` (#C31E49) on `cream` (#F6F1DE): 5.15:1
/// - `paper` (#FFFFFF) on `studentBlue` (#1B56D0): 5.84:1 (CVD-safe vs crimson)
/// - `ink` (#292927) on `orange` (#F38F1D): 6.08:1
/// - `ink` (#292927) on `warn` (#F2B705): 8.02:1
/// - `control` (#7A7260) on `cream` (#F6F1DE): 4.21:1
class SoroTokens {
  SoroTokens._();

  // Brand & Surface Colours
  static const Color cream = Color(0xFFF6F1DE);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color sand = Color(0xFFEAE3CA);
  static const Color ink = Color(0xFF292927);
  static const Color ink2 = Color(0xFF565044);
  static const Color line = Color(0xFFDDD4BA);
  static const Color control = Color(0xFF7A7260);
  static const Color dot = Color(0xFFCCC2A8);

  // Tutor, Student & Semantic Accents
  static const Color crimson = Color(0xFFC31E49);
  static const Color crimsonDeep = Color(0xFF9E1539);
  static const Color orange = Color(0xFFF38F1D);
  static const Color studentBlue = Color(0xFF1B56D0);
  static const Color success = Color(0xFF1D7A48);
  static const Color successDeep = Color(0xFF145A34);
  static const Color warn = Color(0xFFF2B705);

  // Harmonised Pastels (all >= 10.3:1 with ink #292927)
  static const Color sky = Color(0xFFD2E8F8);
  static const Color skyDeep = Color(0xFFEBF4FC);
  static const Color sun = Color(0xFFFFD470);
  static const Color sticky = Color(0xFFFFE580);
  static const Color stickyCurl = Color(0xFFEFC646);
  static const Color mint = Color(0xFFCBEAD4);
  static const Color blush = Color(0xFFFAD2DC);
  static const Color lilac = Color(0xFFE5D4F3);
  static const Color peach = Color(0xFFFFE0BE);

  // Radii
  static const double rSm = 10.0;
  static const double rMd = 20.0;
  static const double rLg = 28.0;
  static const double rPill = 999.0;

  // 4-pt Spacing Grid & Dot Grid
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;
  static const double dotGridSize = 16.0;

  // Minimum touch target for Android tablet stylus & finger use
  static const double minTapTarget = 48.0;

  // Motion durations
  static const Duration mFast = Duration(milliseconds: 120);
  static const Duration mBase = Duration(milliseconds: 220);
  static const Duration mMorph = Duration(milliseconds: 320);

  // Warm low-elevation shadows (never cold grey)
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color.fromRGBO(92, 74, 42, 0.08),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color.fromRGBO(92, 74, 42, 0.12),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> e3 = [
    BoxShadow(
      color: Color.fromRGBO(92, 74, 42, 0.16),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  // Font families (bundled full-coverage variable TTFs for Yorùbá GPOS mark/mkmk)
  static const String fontSerif = 'SourceSerif4';
  static const String fontSans = 'Inter';

  /// Yorùbá-safe Source Serif 4 headline style (zero letter-spacing, unclipped height).
  static TextStyle serif({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w500,
    Color color = ink,
    double height = 1.28,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    final double wght = fontWeight.value.toDouble();
    final double opsz = fontSize.clamp(8.0, 60.0);
    return TextStyle(
      fontFamily: fontSerif,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: 0,
      fontVariations: [
        FontVariation('wght', wght),
        FontVariation('opsz', opsz),
      ],
    );
  }

  /// Yorùbá-safe Inter UI & body style (zero letter-spacing, unclipped height, tabular figures optional).
  static TextStyle sans({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = ink,
    double height = 1.5,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    final double wght = fontWeight.value.toDouble();
    return TextStyle(
      fontFamily: fontSans,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: 0,
      fontVariations: [
        FontVariation('wght', wght),
      ],
    );
  }

  static ThemeData buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      fontFamily: fontSans,
      colorScheme: const ColorScheme.light(
        primary: crimson,
        onPrimary: paper,
        secondary: orange,
        onSecondary: ink,
        tertiary: studentBlue,
        onTertiary: paper,
        surface: paper,
        onSurface: ink,
        outline: control,
      ),
    );

    return base.copyWith(
      textTheme: TextTheme(
        displayLarge: serif(fontSize: 40, fontWeight: FontWeight.w500),
        displayMedium: serif(fontSize: 32, fontWeight: FontWeight.w500),
        headlineMedium: serif(fontSize: 28, fontWeight: FontWeight.w500),
        headlineSmall: serif(fontSize: 22, fontWeight: FontWeight.w600),
        titleLarge: serif(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: sans(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: sans(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: sans(fontSize: 15, fontWeight: FontWeight.w400),
        labelLarge: sans(fontSize: 14, fontWeight: FontWeight.w600),
        bodySmall: sans(fontSize: 13.5, fontWeight: FontWeight.w400, color: ink2),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// Plain white study background shared by every screen. The dotted paper and
/// watermark were retired; [showWatermark] is kept so call sites still compile.
class SoroDottedPaperBackground extends StatelessWidget {
  const SoroDottedPaperBackground({
    super.key,
    required this.child,
    this.showWatermark = false,
  });

  final Widget child;
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: SoroTokens.paper, child: child);
  }
}
