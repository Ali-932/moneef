import 'package:flutter/material.dart';

/// Design tokens so screens stay visually consistent. Add new tokens here
/// rather than inlining `Color` literals in screens.
///
/// `AppColors` is a [ThemeExtension]: widgets resolve the active palette via
/// `AppColors.of(context)` (light or dark). Because ThemeExtensions lerp,
/// toggling dark mode cross-fades every color in the app smoothly.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primarySoft,
    required this.incomeBg,
    required this.expenseBg,
    required this.surface,
    required this.card,
    required this.tile,
    required this.ink,
    required this.muted,
    required this.subtle,
    required this.divider,
    required this.positiveText,
    required this.negativeText,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.skeleton,
    required this.accentFill,
  });

  final Color primary;
  final Color primarySoft;
  final Color incomeBg;
  final Color expenseBg;
  final Color surface;
  final Color card;
  final Color tile;
  final Color ink;
  // Secondary/tertiary text. Both palettes clear WCAG AA (>=4.5:1): `muted`
  // passes on card/tile/tints; `subtle` (timestamps) passes on card.
  final Color muted;
  final Color subtle;
  final Color divider;
  final Color positiveText;
  final Color negativeText;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color skeleton;

  /// Solid fill safe for a white foreground in both themes — used for
  /// chip/segment/button fills. `primary` stays reserved for icon tints,
  /// links and borders; it's deliberately lifted in dark mode for
  /// visibility against dark surfaces, which makes it too light for white
  /// text on top of it (white-on-#8B80F0 = 3.26:1, fails AA).
  final Color accentFill;

  static const light = AppColors(
    primary: Color(0xFF6250D5),
    primarySoft: Color(0xFFEDE9FE),
    incomeBg: Color(0xFFEAF5EF),
    expenseBg: Color(0xFFFAEEF0),
    surface: Color(0xFFF6F6FA),
    card: Colors.white,
    tile: Color(0xFFF1F2F6),
    ink: Color(0xFF252336),
    muted: Color(0xFF5B6573),
    subtle: Color(0xFF6A7280),
    divider: Color(0xFFEAEDF2),
    positiveText: Color(0xFF1A7536),
    negativeText: Color(0xFFAD3952),
    shimmerBase: Color(0xFFE7E9EF),
    shimmerHighlight: Color(0xFFF4F5F9),
    skeleton: Color(0xFFF1F2F6),
    accentFill: Color(0xFF6C5CE7),
  );

  /// Calm dark palette: near-black violet-tinted neutrals, lifted accents so
  /// income/expense text keeps AA contrast on dark cards. No neon.
  static const dark = AppColors(
    primary: Color(0xFF9B8DF1),
    primarySoft: Color(0xFF2B2750),
    incomeBg: Color(0xFF1E3326),
    expenseBg: Color(0xFF3A2128),
    surface: Color(0xFF13141A),
    card: Color(0xFF1C1E26),
    tile: Color(0xFF262934),
    ink: Color(0xFFF0F1F5),
    muted: Color(0xFF9CA4B4),
    subtle: Color(0xFF8A92A2),
    divider: Color(0xFF2C2F3A),
    positiveText: Color(0xFF63D68E),
    negativeText: Color(0xFFF27E93),
    shimmerBase: Color(0xFF262934),
    shimmerHighlight: Color(0xFF313543),
    skeleton: Color(0xFF262934),
    accentFill: Color(0xFF6C5CE7),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? primary,
    Color? primarySoft,
    Color? incomeBg,
    Color? expenseBg,
    Color? surface,
    Color? card,
    Color? tile,
    Color? ink,
    Color? muted,
    Color? subtle,
    Color? divider,
    Color? positiveText,
    Color? negativeText,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? skeleton,
    Color? accentFill,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      incomeBg: incomeBg ?? this.incomeBg,
      expenseBg: expenseBg ?? this.expenseBg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      tile: tile ?? this.tile,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      divider: divider ?? this.divider,
      positiveText: positiveText ?? this.positiveText,
      negativeText: negativeText ?? this.negativeText,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      skeleton: skeleton ?? this.skeleton,
      accentFill: accentFill ?? this.accentFill,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      incomeBg: Color.lerp(incomeBg, other.incomeBg, t)!,
      expenseBg: Color.lerp(expenseBg, other.expenseBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      tile: Color.lerp(tile, other.tile, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      positiveText: Color.lerp(positiveText, other.positiveText, t)!,
      negativeText: Color.lerp(negativeText, other.negativeText, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      accentFill: Color.lerp(accentFill, other.accentFill, t)!,
    );
  }
}

/// Shorthand: `context.palette.ink` instead of `AppColors.of(context).ink`.
extension AppPaletteX on BuildContext {
  AppColors get palette => AppColors.of(this);
}

/// Shared motion tokens so every animated widget uses the same rhythm.
/// Durations stay in the 100-350ms band; anything slower feels sluggish on
/// a finance app where users tap rapidly.
class AppMotion {
  AppMotion._();

  static const press = Duration(milliseconds: 100);
  static const chip = Duration(milliseconds: 200);
  static const iconSwap = Duration(milliseconds: 200);
  static const indicator = Duration(milliseconds: 250);
  static const sectionSwitch = Duration(milliseconds: 250);
  static const page = Duration(milliseconds: 240);
  static const theme = Duration(milliseconds: 250);
  static const reducedFallback = Duration(milliseconds: 120);

  static const entrance = Curves.easeOutCubic;
  static const exit = Curves.easeIn;
  static const emphasized = Curves.easeInOut;
}

class AppRadii {
  AppRadii._();
  static const small = BorderRadius.all(Radius.circular(8));
  static const medium = BorderRadius.all(Radius.circular(12));
  static const large = BorderRadius.all(Radius.circular(16));
  static const pill = BorderRadius.all(Radius.circular(999));
}

ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      surface: palette.surface,
    ),
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: palette.surface,
  );

  return base.copyWith(
    extensions: [palette],
    dialogTheme: DialogThemeData(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.divider),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: palette.ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: palette.muted,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    datePickerTheme: _datePickerTheme(palette),
    textTheme: base.textTheme
        .apply(bodyColor: palette.ink, displayColor: palette.ink)
        .copyWith(
          bodyLarge: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            height: 1.45,
            color: palette.ink,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            height: 1.4,
            color: palette.ink,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.muted,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12,
        color: palette.muted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: palette.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: palette.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.card,
      border: const OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide(color: palette.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide(color: palette.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(
        color: palette.muted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(color: palette.muted, fontSize: 13),
    ),
    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accentFill,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
      ),
    ),
    // Floating (not fixed) so the docked center FAB doesn't get shoved up
    // above the snackbar and snap back. Floating snackbars never displace the
    // FAB; fixed ones do.
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

DatePickerThemeData _datePickerTheme(AppColors palette) {
  final foreground = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return palette.muted.withValues(alpha: .45);
    }
    if (states.contains(WidgetState.selected)) return Colors.white;
    return palette.ink;
  });
  final background = WidgetStateProperty.resolveWith<Color?>((states) {
    return states.contains(WidgetState.selected)
        ? palette.accentFill
        : Colors.transparent;
  });
  const headline = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -.8,
  );
  const label = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  const dayShape = WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(borderRadius: AppRadii.medium),
  );

  return DatePickerThemeData(
    backgroundColor: palette.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    headerBackgroundColor: palette.primarySoft,
    headerForegroundColor: palette.primary,
    headerHeadlineStyle: headline,
    headerHelpStyle: label,
    subHeaderForegroundColor: palette.ink,
    toggleButtonTextStyle: label.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    weekdayStyle: label.copyWith(color: palette.muted, fontSize: 12),
    dayStyle: label.copyWith(fontSize: 14),
    dayForegroundColor: foreground,
    dayBackgroundColor: background,
    dayShape: dayShape,
    todayForegroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.white
          : palette.primary,
    ),
    todayBackgroundColor: background,
    todayBorder: BorderSide(color: palette.primary),
    yearStyle: label.copyWith(fontSize: 15),
    yearForegroundColor: foreground,
    yearBackgroundColor: background,
    yearShape: dayShape,
    dividerColor: palette.divider,
    rangePickerBackgroundColor: palette.card,
    rangePickerSurfaceTintColor: Colors.transparent,
    rangePickerElevation: 0,
    rangePickerHeaderBackgroundColor: palette.primarySoft,
    rangePickerHeaderForegroundColor: palette.primary,
    rangePickerHeaderHeadlineStyle: headline.copyWith(fontSize: 26),
    rangePickerHeaderHelpStyle: label,
    rangeSelectionBackgroundColor: palette.primarySoft,
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: palette.muted,
      minimumSize: const Size(80, 48),
      textStyle: label.copyWith(fontSize: 14),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
    confirmButtonStyle: TextButton.styleFrom(
      backgroundColor: palette.accentFill,
      foregroundColor: Colors.white,
      minimumSize: const Size(108, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      textStyle: label.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
  );
}
