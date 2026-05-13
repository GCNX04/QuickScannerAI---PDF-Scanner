/// Metadata for a saved PDF stored on disk.
class ScanRecord {
  const ScanRecord({
    required this.path,
    required this.title,
    required this.createdMs,
    this.thumbPath,
  });

  final String path;
  final String title;
  final int createdMs;

  /// Optional JPEG preview written next to the PDF (same basename `_thumb.jpg`).
  final String? thumbPath;

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'createdMs': createdMs,
        if (thumbPath != null) 'thumbPath': thumbPath,
      };

  static ScanRecord? fromJson(dynamic item) {
    if (item is! Map<String, dynamic>) return null;
    final path = item['path'];
    final title = item['title'];
    final createdMs = item['createdMs'];
    final thumbPath = item['thumbPath'];
    if (path is! String || title is! String || createdMs is! int) {
      return null;
    }
    return ScanRecord(
      path: path,
      title: title,
      createdMs: createdMs,
      thumbPath: thumbPath is String ? thumbPath : null,
    );
  }
}
