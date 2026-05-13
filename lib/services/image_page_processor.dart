import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Visual filter presets for scanned pages (inspired by document scanner apps).
enum ScanFilter {
  auto,
  bw,
  color,
  photo,
}

/// CPU-side image transforms used before PDF export.
class ImagePageProcessor {
  ImagePageProcessor._();

  /// Renders [originalJpegBytes] with rotation, filter, optional mild deskew polish.
  ///
  /// When [thumbMaxEdge] is set, the result is downscaled so the longest side equals
  /// that value (faster encoding for filter strip thumbnails).
  static Uint8List render({
    required Uint8List originalJpegBytes,
    int rotationQuarterTurns = 0,
    ScanFilter filter = ScanFilter.auto,
    bool curvatureCorrection = false,
    int? thumbMaxEdge,
  }) {
    final decoded = img.decodeImage(originalJpegBytes);
    if (decoded == null) return originalJpegBytes;

    var image = img.Image.from(decoded);

    final turns = rotationQuarterTurns % 4;
    if (turns == 1) {
      image = img.copyRotate(image, angle: 90);
    } else if (turns == 2) {
      image = img.copyRotate(image, angle: 180);
    } else if (turns == 3) {
      image = img.copyRotate(image, angle: 270);
    }

    image = _applyFilter(image, filter);

    if (curvatureCorrection) {
      image = img.adjustColor(image, contrast: 1.05, saturation: 1.02);
    }

    if (thumbMaxEdge != null && thumbMaxEdge > 0) {
      final w = image.width;
      final h = image.height;
      if (w > thumbMaxEdge || h > thumbMaxEdge) {
        if (w >= h) {
          image = img.copyResize(
            image,
            width: thumbMaxEdge,
            maintainAspect: true,
            interpolation: img.Interpolation.linear,
          );
        } else {
          image = img.copyResize(
            image,
            height: thumbMaxEdge,
            maintainAspect: true,
            interpolation: img.Interpolation.linear,
          );
        }
      }
    }

    final q = thumbMaxEdge != null ? 78 : 92;
    return Uint8List.fromList(img.encodeJpg(image, quality: q));
  }

  /// Fast resize-only preview for recent-list thumbnails (already color-corrected bytes).
  static Uint8List previewResizeOnly(Uint8List jpegBytes, {int maxEdge = 160}) {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) return jpegBytes;
    var image = img.Image.from(decoded);
    final w = image.width;
    final h = image.height;
    if (w > maxEdge || h > maxEdge) {
      if (w >= h) {
        image = img.copyResize(
          image,
          width: maxEdge,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
      } else {
        image = img.copyResize(
          image,
          height: maxEdge,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 82));
  }

  /// Trims a small border (quick "recrop" without a full crop UI).
  static Uint8List trimMargins(Uint8List originalJpegBytes, {double fraction = 0.04}) {
    final decoded = img.decodeImage(originalJpegBytes);
    if (decoded == null) return originalJpegBytes;
    final w = decoded.width;
    final h = decoded.height;
    final dx = (w * fraction).round().clamp(1, w ~/ 4);
    final dy = (h * fraction).round().clamp(1, h ~/ 4);
    final cropped = img.copyCrop(
      decoded,
      x: dx,
      y: dy,
      width: (w - 2 * dx).clamp(1, w),
      height: (h - 2 * dy).clamp(1, h),
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  }

  static img.Image _applyFilter(img.Image image, ScanFilter filter) {
    switch (filter) {
      case ScanFilter.auto:
        return img.adjustColor(
          image,
          contrast: 1.12,
          saturation: 1.05,
          brightness: 1.02,
        );
      case ScanFilter.bw:
        final g = img.grayscale(img.Image.from(image));
        return img.adjustColor(g, contrast: 1.22, brightness: 1.01);
      case ScanFilter.color:
        return img.adjustColor(
          image,
          saturation: 1.14,
          contrast: 1.06,
        );
      case ScanFilter.photo:
        return img.adjustColor(
          image,
          contrast: 0.94,
          saturation: 0.92,
          brightness: 1.03,
        );
    }
  }
}
