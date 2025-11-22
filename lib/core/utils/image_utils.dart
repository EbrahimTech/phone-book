import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageUtils {
  /// Compress and optimize image
  static Future<File?> compressImage(File imageFile, {int quality = 85, int maxSize = 1024}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalSize = bytes.length / 1024; // KB

      // If image is already small enough, return as is
      if (originalSize <= maxSize) {
        return imageFile;
      }

      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Calculate new dimensions to reduce size
      double scale = 1.0;
      if (originalSize > maxSize) {
        scale = (maxSize / originalSize).clamp(0.5, 1.0);
      }

      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();

      // Resize image
      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode with quality
      final compressedBytes = img.encodeJpg(resized, quality: quality);

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(imageFile.path);
      final compressedFile = File(path.join(tempDir.path, 'compressed_$fileName'));

      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      return imageFile; // Return original if compression fails
    }
  }

  /// Get image file extension
  static String getImageExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  /// Check if file is valid image
  static bool isValidImage(String filePath) {
    final ext = getImageExtension(filePath);
    return ext == '.png' || ext == '.jpg' || ext == '.jpeg';
  }
}

