import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ColorUtils {
  /// Extract dominant color from image file
  static Future<Color> getDominantColor(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return Colors.grey;
      }

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return Colors.grey;
      }

      // Resize image for faster processing
      final resized = img.copyResize(image, width: 100);
      
      // Calculate average color using sample points
      int r = 0, g = 0, b = 0;
      int pixelCount = 0;

      // Sample pixels (every 5th pixel for performance)
      for (int y = 0; y < resized.height; y += 5) {
        for (int x = 0; x < resized.width; x += 5) {
          final pixel = resized.getPixel(x, y);
          // Use the pixel's r, g, b properties directly
          r += pixel.r.toInt();
          g += pixel.g.toInt();
          b += pixel.b.toInt();
          pixelCount++;
        }
      }

      if (pixelCount == 0) {
        return Colors.grey;
      }

      r = (r / pixelCount).round();
      g = (g / pixelCount).round();
      b = (b / pixelCount).round();

      return Color.fromRGBO(r, g, b, 1.0);
    } catch (e) {
      return Colors.grey;
    }
  }

  /// Extract dominant color from network image
  static Future<Color> getDominantColorFromNetwork(String imageUrl) async {
    try {
      // For network images, we'll use a simpler approach
      // In production, you might want to download and process the image
      return Colors.grey;
    } catch (e) {
      return Colors.grey;
    }
  }

  /// Get shadow color based on dominant color
  static Color getShadowColor(Color dominantColor) {
    // Make shadow darker and more transparent
    return dominantColor.withOpacity(0.3);
  }
}

