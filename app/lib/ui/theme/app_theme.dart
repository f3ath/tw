import 'package:app/ui/theme/app_colors.dart';
import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static final light = _build(AppColors.light);
  static final dark = _build(AppColors.dark);

  static const _heading = TextStyle(fontWeight: FontWeight.w700);
  static const _label = TextStyle(fontWeight: FontWeight.w400);

  static ThemeData _build(ColorScheme colors) => ThemeData(
    colorScheme: colors,
    fontFamily: 'Noto Sans',
    textTheme: const TextTheme(
      displayLarge: _heading,
      displayMedium: _heading,
      displaySmall: _heading,
      headlineLarge: _heading,
      headlineMedium: _heading,
      headlineSmall: _heading,
      titleLarge: _heading,
      titleMedium: _heading,
      titleSmall: _heading,
      labelLarge: _label,
      labelMedium: _label,
      labelSmall: _label,
    ),
  );
}
