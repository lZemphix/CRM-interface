import 'package:flutter/material.dart';

import 'light/colorscheme.dart';

/// Semantic colors from the approved HTML prototype. The interpolation factor
/// lets AnimatedTheme blend both palettes without mutable global colors.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette._(this.darkness);
  static const light = AppPalette._(0);
  static const dark = AppPalette._(1);
  final double darkness;

  Color _color(Color light, int dark) =>
      Color.lerp(light, Color(dark), darkness)!;

  Color get background => _color(AppColors.background, 0xFF141C29);
  Color get surface => _color(Colors.white, 0xFF1C2535);
  Color get surfaceMuted => _color(const Color(0xFFF2F4F7), 0xFF283347);
  Color get text => _color(const Color(0xFF172033), 0xFFE8EDF6);
  Color get taskCardText => text;
  Color get sidebarBackground =>
      _color(AppColors.sidebarBackground, 0xFF0B101C);
  Color get taskColumnBackground =>
      _color(AppColors.taskColumnBackground, 0xFF192231);
  Color get taskCardBackground => surface;
  Color get taskCardShadow => _color(AppColors.taskCardShadow, 0x26000000);
  Color get ownTaskBackground =>
      _color(AppColors.ownTaskBackground, 0xFF21364D);
  Color get ownTaskBorder => _color(AppColors.ownTaskBorder, 0xFF4B749A);
  Color get ownTaskAccent => _color(AppColors.ownTaskAccent, 0xFF8CBCEC);
  Color get ownTaskBadgeBackground =>
      _color(AppColors.ownTaskBadgeBackground, 0xFF304F70);
  Color get ownTaskText => _color(AppColors.ownTaskText, 0xFFBCDDFB);
  Color get taskHighPriority => _color(AppColors.taskHighPriority, 0xFFD69A77);
  Color get taskUrgentPriority =>
      _color(AppColors.taskUrgentPriority, 0xFFDF8E8E);
  Color get normalPriority => _color(AppColors.activeElement, 0xFFA5A5E8);
  Color get activeElement => _color(AppColors.activeElement, 0xFF6262D9);
  Color get activeElementHover =>
      _color(AppColors.activeElementHover, 0xFF7474E8);
  Color get accent => _color(AppColors.activeElement, 0xFFA4A4FF);
  Color get accentSoft => _color(const Color(0xFFEEEEFF), 0xFF303052);
  Color get accentBorder => _color(const Color(0xFFD5D5FF), 0xFF59598E);
  Color get strongBorder => _color(AppColors.strongBorder, 0xFF45536C);
  Color get notActiveBorder => _color(AppColors.notActiveBorder, 0xFF303C50);
  Color get textFaint => _color(AppColors.textFaint, 0xFF8E9EB7);
  Color get textMutted => _color(AppColors.textMutted, 0xFFB1BED2);
  Color get hoveredElement => _color(AppColors.hoveredElement, 0xFF192234);
  Color get sidebarElement => _color(AppColors.sidebarElement, 0xFF8E9EB7);
  Color get iconBackground1 => _color(const Color(0xFFEEEEFF), 0xFF303052);
  Color get iconBackground2 => _color(const Color(0xFFD9D9FF), 0xFF41416C);
  Color get sidebarAvatarBackground => const Color(0xFF344054);
  Color get sidebarAvatarText => const Color(0xFFDDE2E8);
  Color get track => _color(const Color(0xFFEAECF0), 0xFF354158);
  Color get danger => _color(const Color(0xFFB42318), 0xFFFFA59E);
  Color get dangerSoft => _color(const Color(0xFFFFF1EE), 0xFF442C35);
  Color get dangerFill => const Color(0xFFB42318);
  Color get success => _color(const Color(0xFF21865D), 0xFF7ED7AC);
  Color get successSoft => _color(const Color(0xFFEAF6EF), 0xFF223E36);
  Color get warning => _color(const Color(0xFF9A6700), 0xFFE8C07E);
  Color get warningSoft => _color(const Color(0xFFFFF4E5), 0xFF433A2D);
  Color get queue => _color(const Color(0xFF7C3AED), 0xFFC5A5FF);
  Color get queueSoft => _color(const Color(0xFFF3E8FF), 0xFF352D4D);
  Color get onAccent => Colors.white;

  @override
  AppPalette copyWith({double? darkness}) =>
      AppPalette._(darkness ?? this.darkness);

  @override
  AppPalette lerp(covariant AppPalette? other, double t) => other == null
      ? this
      : AppPalette._(darkness + (other.darkness - darkness) * t);
}

extension AppPaletteContext on BuildContext {
  AppPalette get colors {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
  }
}

ThemeData buildAppTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: colors.activeElement,
        brightness: brightness,
      ).copyWith(
        primary: colors.activeElement,
        onPrimary: colors.onAccent,
        primaryContainer: colors.accentSoft,
        onPrimaryContainer: colors.accent,
        surface: colors.surface,
        surfaceDim: colors.background,
        surfaceBright: colors.surface,
        surfaceContainerLowest: colors.background,
        surfaceContainerLow: colors.background,
        surfaceContainer: colors.surface,
        surfaceContainerHigh: colors.surfaceMuted,
        surfaceContainerHighest: colors.surfaceMuted,
        onSurface: colors.text,
        onSurfaceVariant: colors.textMutted,
        outline: colors.strongBorder,
        outlineVariant: colors.notActiveBorder,
        error: colors.danger,
        errorContainer: colors.dangerSoft,
        onError: brightness == Brightness.dark
            ? colors.dangerSoft
            : colors.onAccent,
        onErrorContainer: colors.danger,
        surfaceTint: Colors.transparent,
        inverseSurface: brightness == Brightness.dark
            ? colors.text
            : colors.sidebarBackground,
        onInverseSurface: brightness == Brightness.dark
            ? colors.background
            : colors.onAccent,
      );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    extensions: [colors],
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    dividerColor: colors.notActiveBorder,
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.textFaint
              : colors.accent,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.textFaint
              : colors.accent,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: colors.surface,
      hintStyle: TextStyle(color: colors.textFaint),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: colors.strongBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.strongBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.accent),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}
