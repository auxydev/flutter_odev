import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const brandColor = Color(0xFF0E7C66);
const brandDark = Color(0xFF053F31);
const appFontFamily = 'PlusJakartaSans';

/// Marka gradyanı (özet kartı, giriş ekranı başlığı, avatar).
const brandGradient = LinearGradient(
  colors: [Color(0xFF12957A), brandColor, brandDark],
  stops: [0, 0.45, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// Ekranın arka planı (kartlar bunun üstünde beyaz durur).
Color pageBackground(Brightness b) =>
    b == Brightness.light ? const Color(0xFFF3F5F4) : const Color(0xFF0C110F);

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final base = ColorScheme.fromSeed(seedColor: brandColor, brightness: brightness);
  final scheme = light
      ? base.copyWith(
          primary: brandColor,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFDDF2EA),
          onPrimaryContainer: const Color(0xFF053D2F),
          secondaryContainer: const Color(0xFFE7F1ED),
          onSecondaryContainer: const Color(0xFF0B3B2F),
          tertiary: const Color(0xFFB45309),
          tertiaryContainer: const Color(0xFFFEF3C7),
          onTertiaryContainer: const Color(0xFF78350F),
          surface: Colors.white,
          onSurface: const Color(0xFF101828),
          onSurfaceVariant: const Color(0xFF667085),
          outline: const Color(0xFFD0D5DD),
          outlineVariant: const Color(0xFFE6E9EE),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF9FAFA),
          surfaceContainer: const Color(0xFFF2F4F3),
          surfaceContainerHigh: const Color(0xFFEBEEED),
          surfaceContainerHighest: const Color(0xFFE4E8E6),
          inverseSurface: const Color(0xFF101828),
          onInverseSurface: Colors.white,
        )
      : base.copyWith(
          primary: const Color(0xFF3DD6A3),
          onPrimary: const Color(0xFF02281D),
          primaryContainer: const Color(0xFF0B4D3C),
          onPrimaryContainer: const Color(0xFFC9F5E3),
          secondaryContainer: const Color(0xFF17302A),
          onSecondaryContainer: const Color(0xFFCFE9DF),
          tertiary: const Color(0xFFFBBF24),
          surface: const Color(0xFF151B19),
          onSurface: const Color(0xFFE9EEEC),
          onSurfaceVariant: const Color(0xFF98A29F),
          outline: const Color(0xFF3A4440),
          outlineVariant: const Color(0xFF242D2A),
          surfaceContainerLowest: const Color(0xFF0C110F),
          surfaceContainerLow: const Color(0xFF121816),
          surfaceContainer: const Color(0xFF1A2220),
          surfaceContainerHigh: const Color(0xFF212A27),
          surfaceContainerHighest: const Color(0xFF29332F),
        );

  final background = pageBackground(brightness);
  final radius = BorderRadius.circular(14);
  final text = _textTheme(brightness, scheme);

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: background,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: text.headlineSmall,
      systemOverlayStyle: light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : scheme.surfaceContainer,
      border: border(scheme.outlineVariant),
      enabledBorder: border(light ? const Color(0xFFDDE2E7) : scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 1.6),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.6),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: light ? 0.1 : 0.18),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: appFontFamily,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      showCheckmark: false,
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      side: WidgetStateBorderSide.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? BorderSide(color: scheme.primary)
            : BorderSide(color: scheme.outlineVariant),
      ),
      // Seçili/seçisiz yazı rengi çiplerde ayrıca verilir (bkz. HistoryScreen).
      labelStyle: TextStyle(
        fontFamily: appFontFamily,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: text.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: appFontFamily,
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}

TextTheme _textTheme(Brightness brightness, ColorScheme scheme) {
  final typography = Typography.material2021(platform: TargetPlatform.android);
  // black/white yalnızca renk içerir; boyutlar englishLike'tan gelir.
  final colors = brightness == Brightness.light ? typography.black : typography.white;
  final base = typography.englishLike.merge(colors).apply(
    fontFamily: appFontFamily,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  // Tutarlar alt alta düzgün hizalansın diye sabit genişlikli rakamlar.
  TextStyle? s(TextStyle? style, FontWeight weight, [double letterSpacing = 0]) => style?.copyWith(
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  return base.copyWith(
    displaySmall: s(base.displaySmall, FontWeight.w800, -1.2),
    headlineLarge: s(base.headlineLarge, FontWeight.w800, -1),
    headlineMedium: s(base.headlineMedium, FontWeight.w800, -0.8),
    headlineSmall: s(base.headlineSmall, FontWeight.w800, -0.5),
    titleLarge: s(base.titleLarge, FontWeight.w700, -0.3),
    titleMedium: s(base.titleMedium, FontWeight.w700, -0.2),
    titleSmall: s(base.titleSmall, FontWeight.w600),
    bodyLarge: s(base.bodyLarge, FontWeight.w500),
    bodyMedium: s(base.bodyMedium, FontWeight.w500),
    bodySmall: s(base.bodySmall, FontWeight.w500),
    labelLarge: s(base.labelLarge, FontWeight.w600),
    labelMedium: s(base.labelMedium, FontWeight.w600),
    labelSmall: s(base.labelSmall, FontWeight.w600),
  );
}
