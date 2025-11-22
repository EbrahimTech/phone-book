import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

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

      final resized = img.copyResize(image, width: 150, height: 150);
      
      int r = 0, g = 0, b = 0;
      int pixelCount = 0;

      for (int y = 0; y < resized.height; y += 3) {
        for (int x = 0; x < resized.width; x += 3) {
          final pixel = resized.getPixel(x, y);
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
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        return Colors.grey;
      }

      final bytes = response.bodyBytes;
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return Colors.grey;
      }

      final resized = img.copyResize(image, width: 150, height: 150);
      
      int r = 0, g = 0, b = 0;
      int pixelCount = 0;

      for (int y = 0; y < resized.height; y += 3) {
        for (int x = 0; x < resized.width; x += 3) {
          final pixel = resized.getPixel(x, y);
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

  /// Get shadow color based on dominant color
  static Color getShadowColor(Color dominantColor) {
    // Make shadow lighter and more transparent for a soft glow effect
    // Adjust brightness to make it more visible
    final hsl = HSLColor.fromColor(dominantColor);
    final lighterColor = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
    return lighterColor.withValues(alpha: 0.25);
  }
}

