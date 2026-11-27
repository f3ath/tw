import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  static const _petrol = Color(0xFF164E55);
  static const _citron = Color(0xFFDAEF91);
  static const _jade = Color(0xFF7FC6B9);
  static const _mist = Color(0xFFE1F4ED);
  static const _ink = Color(0xFF143338);
  static const _paper = Color(0xFFF1F7F4);

  static const _darkErrorFill = Color(0xFF542A32);
  static const _darkErrorLabel = Color(0xFFFFCBC8);
  static const _lightErrorFill = Color(0xFFFCE6E3);
  static const _lightErrorLabel = Color(0xFF8B2C32);

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: _citron,
    onPrimary: _ink,
    primaryContainer: _petrol,
    onPrimaryContainer: _citron,
    secondary: _jade,
    onSecondary: _ink,
    secondaryContainer: _petrol,
    onSecondaryContainer: _mist,
    surface: _ink,
    onSurface: _mist,
    onSurfaceVariant: Color(0xFFBDD7D3),
    surfaceContainerLow: Color(0xFF193D43),
    surfaceContainer: Color(0xFF1C454B),
    surfaceContainerHigh: _petrol,
    surfaceContainerHighest: Color(0xFF245C62),
    outline: Color(0xFF8DB5B3),
    outlineVariant: Color(0xFF43686C),
    inverseSurface: _mist,
    onInverseSurface: _ink,
    inversePrimary: _petrol,
    error: _darkErrorLabel,
    onError: _darkErrorFill,
    errorContainer: _darkErrorFill,
    onErrorContainer: _darkErrorLabel,
  );

  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: _petrol,
    onPrimary: _mist,
    primaryContainer: _jade,
    onPrimaryContainer: _ink,
    secondary: _ink,
    onSecondary: _mist,
    secondaryContainer: _mist,
    onSecondaryContainer: _ink,
    surface: _paper,
    onSurface: _ink,
    onSurfaceVariant: Color(0xFF38575B),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF9FCFB),
    surfaceContainer: _mist,
    surfaceContainerHigh: Color(0xFFD8ECE5),
    surfaceContainerHighest: Color(0xFFCDE5DE),
    outline: Color(0xFF5E7A78),
    outlineVariant: Color(0xFFC2D6D0),
    inverseSurface: _ink,
    onInverseSurface: _mist,
    inversePrimary: _citron,
    error: _lightErrorLabel,
    onError: _lightErrorFill,
    errorContainer: _lightErrorFill,
    onErrorContainer: _lightErrorLabel,
  );

  static ({Color fill, Color label}) scheduleStatus(ColorScheme scheme, {required bool overdue}) {
    if (overdue) return (fill: scheme.errorContainer, label: scheme.onErrorContainer);
    return scheme.brightness == Brightness.dark
        ? (fill: const Color(0xFF453817), label: const Color(0xFFFFE5A0))
        : (fill: const Color(0xFFFFF0C4), label: const Color(0xFF604500));
  }
}
