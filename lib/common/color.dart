import 'dart:math';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_color_utilities/hct/hct.dart';
import 'package:material_ui/material_ui.dart';

extension ColorExtension on Color {
  Color get opacity80 {
    return withValues(alpha: 0.8);
  }

  Color get opacity60 {
    return withValues(alpha: 0.6);
  }

  Color get opacity50 {
    return withValues(alpha: 0.5);
  }

  Color get opacity38 {
    return withValues(alpha: 0.38);
  }

  Color get opacity30 {
    return withValues(alpha: 0.3);
  }

  Color get opacity12 {
    return withValues(alpha: 0.12);
  }

  Color get opacity15 {
    return withValues(alpha: 0.15);
  }

  Color get opacity10 {
    return withValues(alpha: 0.1);
  }

  Color get opacity3 {
    return withValues(alpha: 0.03);
  }

  Color get opacity0 {
    return withValues(alpha: 0);
  }

  int get value32bit {
    return _floatToInt8(a) << 24 |
        _floatToInt8(r) << 16 |
        _floatToInt8(g) << 8 |
        _floatToInt8(b) << 0;
  }

  int get alpha8bit => (0xff000000 & value32bit) >> 24;

  int get red8bit => (0x00ff0000 & value32bit) >> 16;

  int get green8bit => (0x0000ff00 & value32bit) >> 8;

  int get blue8bit => (0x000000ff & value32bit) >> 0;

  int _floatToInt8(double x) {
    return (x * 255.0).round() & 0xff;
  }

  Color lighten([double amount = 10]) {
    if (amount <= 0) return this;
    if (amount > 100) return Colors.white;
    final HSLColor hsl = this == const Color(0xFF000000)
        ? HSLColor.fromColor(this).withSaturation(0)
        : HSLColor.fromColor(this);
    return hsl
        .withLightness(min(1, max(0, hsl.lightness + amount / 100)))
        .toColor();
  }

  String get hex {
    final value = toARGB32();
    final red = (value >> 16) & 0xFF;
    final green = (value >> 8) & 0xFF;
    final blue = value & 0xFF;
    return '#${red.toRadixString(16).padLeft(2, '0')}'
            '${green.toRadixString(16).padLeft(2, '0')}'
            '${blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Color blendDarken(BuildContext context, {double factor = 0.1}) {
    final brightness = Theme.of(context).brightness;
    return Color.lerp(
      this,
      brightness == Brightness.dark ? Colors.white : Colors.black,
      factor,
    )!;
  }
}

const _dotMatrixPanel = Color(0xFF0C0C0C);
const _dotMatrixHairline = Color(0xFF262626);
const _dotMatrixText = Color(0xFFF2F2F2);
const _dotMatrixSelectedTint = 0.16;
const _dotMatrixGreen = Color(0xFF3DDC84);
const _dotMatrixYellow = Color(0xFFFFD60A);
const _dotMatrixRed = Color(0xFFFF5247);

const _labPanel = Color(0xFFFAF9F6);
const _labHairline = Color(0xFFD9D6CE);
const _labInk = Color(0xFF141414);

extension ColorSchemeExtension on ColorScheme {
  /// Replaces only a light scheme's neutrals; the accents stay the seed's own.
  ColorScheme toLab() {
    if (brightness != Brightness.light) {
      return this;
    }
    return copyWith(
      surface: const Color(0xFFEFEDE8),
      surfaceDim: const Color(0xFFE4E1DB),
      surfaceBright: _labPanel,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: _labPanel,
      surfaceContainer: const Color(0xFFF0EEE9),
      surfaceContainerHigh: const Color(0xFFEAE7E1),
      surfaceContainerHighest: _labHairline,
      onSurface: _labInk,
      onSurfaceVariant: const Color(0xFF55524C),
      outline: const Color(0xFF7A766E),
      outlineVariant: _labHairline,
      secondaryContainer: Color.lerp(
        _labPanel,
        primaryContainer,
        _dotMatrixSelectedTint,
      ),
      onSecondaryContainer: _labInk,
    );
  }

  /// Replaces only a dark scheme's neutrals and error; primary stays the seed's.
  ColorScheme toDotMatrix() {
    if (brightness != Brightness.dark) {
      return this;
    }
    return copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceBright: const Color(0xFF2E2E2E),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: _dotMatrixPanel,
      surfaceContainer: const Color(0xFF121212),
      surfaceContainerHigh: const Color(0xFF181818),
      surfaceContainerHighest: _dotMatrixHairline,
      onSurface: _dotMatrixText,
      onSurfaceVariant: const Color(0xFF9A9A9A),
      outline: const Color(0xFF6A6A6A),
      outlineVariant: _dotMatrixHairline,
      secondaryContainer: Color.lerp(
        _dotMatrixPanel,
        primary,
        _dotMatrixSelectedTint,
      ),
      onSecondaryContainer: _dotMatrixText,
      error: _dotMatrixRed,
      onError: Colors.black,
    );
  }

  ColorScheme toPureBlack(bool isPureBlack) {
    if (!isPureBlack || brightness != Brightness.dark) {
      return this;
    }
    final shift = Hct.fromInt(surface.toARGB32()).tone;
    Color lower(Color color) {
      final hct = Hct.fromInt(color.toARGB32());
      return Color(
        Hct.from(hct.hue, hct.chroma, max(0, hct.tone - shift)).toInt(),
      );
    }

    return copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: lower(surfaceContainerLow),
      surfaceContainer: lower(surfaceContainer),
      surfaceContainerHigh: lower(surfaceContainerHigh),
      surfaceContainerHighest: lower(surfaceContainerHighest),
      surfaceBright: lower(surfaceBright),
    );
  }

  Color get modalScrim => scrim.withValues(alpha: 0.32);

  Color get success => brightness == Brightness.dark
      ? _dotMatrixGreen
      : Colors.green.harmonizeWith(primary);

  Color get warning => brightness == Brightness.dark
      ? _dotMatrixYellow
      : Colors.orange.harmonizeWith(primary);

  Color? delayColor(int? delay) {
    if (delay == null) return null;
    if (delay < 0) return error;
    if (delay < 600) return success;
    return warning;
  }
}
