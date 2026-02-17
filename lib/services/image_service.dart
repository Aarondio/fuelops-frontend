import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageService {
  /// Maximum width for compressed images
  static const int maxWidth = 1920;

  /// Maximum height for compressed images
  static const int maxHeight = 1080;

  /// JPEG quality (0-100)
  static const int quality = 70;

  /// Compress an image file and return a new compressed file
  /// Returns the original file if compression fails
  Future<File> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = path.join(
        tempDir.path,
        'compressed_$timestamp.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }

      return file;
    } catch (e) {
      // Return original file if compression fails
      return file;
    }
  }

  /// Compress image and save to app's documents directory for persistence
  /// This ensures images aren't lost if user clears cache
  Future<File> compressAndPersist(File file, String category) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'meter_images'));

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = path.join(
        imagesDir.path,
        '${category}_$timestamp.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }

      // If compression fails, copy original to persistent storage
      final persistedFile = await file.copy(targetPath);
      return persistedFile;
    } catch (e) {
      return file;
    }
  }

  /// Get file size in MB
  Future<double> getFileSizeMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Get compression stats for logging/debugging
  Future<Map<String, dynamic>> getCompressionStats(
    File original,
    File compressed,
  ) async {
    final originalSize = await getFileSizeMB(original);
    final compressedSize = await getFileSizeMB(compressed);
    final savings = ((originalSize - compressedSize) / originalSize) * 100;

    return {
      'originalSizeMB': originalSize.toStringAsFixed(2),
      'compressedSizeMB': compressedSize.toStringAsFixed(2),
      'savingsPercent': savings.toStringAsFixed(1),
    };
  }

  /// Clean up old compressed images (older than 7 days)
  Future<void> cleanupOldImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'meter_images'));

      if (!await imagesDir.exists()) return;

      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final files = await imagesDir.list().toList();

      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}
