import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Best-effort secure deletion for short-lived export/share files.
Future<void> secureDeleteFile(File file, {int maxPassBytes = 8 * 1024 * 1024}) async {
  try {
    if (!await file.exists()) return;
    final len = await file.length();
    if (len == 0) {
      await file.delete();
      return;
    }
    if (len <= maxPassBytes) {
      final rnd = Random.secure();
      final buf = Uint8List(65536);
      final raf = await file.open(mode: FileMode.write);
      try {
        var offset = 0;
        while (offset < len) {
          final chunk = (len - offset) > 65536 ? 65536 : (len - offset);
          for (var i = 0; i < chunk; i++) {
            buf[i] = rnd.nextInt(256);
          }
          await raf.setPosition(offset);
          await raf.writeFrom(buf, 0, chunk);
          offset += chunk;
        }
      } finally {
        await raf.close();
      }
    }
    await file.delete();
  } catch (_) {
    try {
      await file.delete();
    } catch (_) {}
  }
}
