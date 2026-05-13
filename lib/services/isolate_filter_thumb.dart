import 'dart:typed_data';

import 'image_page_processor.dart';

/// Top-level for [compute] — runs image pipeline off the UI isolate.
Uint8List buildFilterThumbIsolate(Map<String, dynamic> message) {
  return ImagePageProcessor.render(
    originalJpegBytes: message['b'] as Uint8List,
    rotationQuarterTurns: message['r'] as int,
    filter: ScanFilter.values[message['f'] as int],
    curvatureCorrection: message['c'] as bool,
    thumbMaxEdge: message['t'] as int? ?? 88,
  );
}

/// Top-level for [compute] — lightweight JPEG resize for recent-list thumbnails.
Uint8List previewResizeIsolate(Uint8List jpegBytes) {
  return ImagePageProcessor.previewResizeOnly(jpegBytes, maxEdge: 160);
}
