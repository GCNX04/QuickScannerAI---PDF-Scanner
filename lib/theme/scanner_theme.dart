import 'package:flutter/material.dart';

import 'app_theme.dart';

/// @deprecated Prefer [AppTheme] / [AppColors] for new code.
abstract final class ScannerTheme {
  static Color get ember => AppColors.ember;

  static ThemeData light() => AppTheme.dark();
}
