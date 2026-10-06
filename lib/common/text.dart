import 'package:fl_clash/enum/enum.dart';
import 'package:material_ui/material_ui.dart';

import 'color.dart';

extension TextStyleExtension on TextStyle {
  TextStyle get toLight => copyWith(color: color?.opacity80);

  TextStyle get toLighter => copyWith(color: color?.opacity60);

  TextStyle get toSoftBold => copyWith(fontWeight: FontWeight.w500);

  TextStyle get toBold => copyWith(fontWeight: FontWeight.bold);

  TextStyle get toJetBrainsMono =>
      copyWith(fontFamily: FontFamily.jetBrainsMono.value);

  TextStyle get toDoto => copyWith(
    fontFamily: FontFamily.doto.value,
    fontVariations: const [FontVariation.weight(900)],
  );

  TextStyle adjustSize(int size) => copyWith(fontSize: fontSize! + size);
}
