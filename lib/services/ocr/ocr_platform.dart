import 'package:flutter/foundation.dart';

/// ML Kit text recognition is only wired for mobile targets in this project.
bool get isMlKitTextRecognitionPlatformSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
