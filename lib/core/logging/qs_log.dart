import 'package:flutter/foundation.dart';

/// Avoids printing sensitive data or noisy logs in release builds.
void qsLog(String message, {Object? error, StackTrace? stackTrace}) {
  if (kReleaseMode) return;
  if (error != null) {
    debugPrint('[QuickScanner] $message: $error');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  } else {
    debugPrint('[QuickScanner] $message');
  }
}
