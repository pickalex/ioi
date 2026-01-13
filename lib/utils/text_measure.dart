import 'package:flutter/material.dart';

/// Utility class for text measurement operations.
class TextMeasure {
  /// Calculates the width of a text string given the text style.
  ///
  /// [text] - The text to measure
  /// [style] - The TextStyle to use for measurement
  /// [letterSpacing] - Optional additional letter spacing
  static double measureTextWidth(
    String text, {
    TextStyle? style,
    double letterSpacing = 0,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style ?? const TextStyle(fontSize: 14)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return textPainter.width + letterSpacing;
  }

  /// Calculates the width of an emoji with default chat style.
  ///
  /// [emoji] - The emoji character(s) to measure
  /// [fontSize] - Font size (default 14)
  static double measureEmojiWidth(String emoji, {double fontSize = 14}) {
    return measureTextWidth(
      emoji,
      style: TextStyle(fontSize: fontSize),
      letterSpacing: 1, // 增加一点间距确保可见
    );
  }
}
