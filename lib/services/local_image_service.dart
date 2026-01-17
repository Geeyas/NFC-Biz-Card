import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for managing local image storage for business cards
class LocalImageService {
  static final LocalImageService _instance = LocalImageService._internal();
  factory LocalImageService() => _instance;
  LocalImageService._internal();

  /// Get the directory for storing card images
  Future<Directory> _getCardImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cardImagesDir = Directory(path.join(appDir.path, 'card_images'));

    if (!await cardImagesDir.exists()) {
      await cardImagesDir.create(recursive: true);
    }

    return cardImagesDir;
  }

  /// Save image locally and return the local path
  /// [cardId] is used to generate unique filename
  Future<String?> saveCardImage(String cardId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('❌ [LocalImage] Source file does not exist: $sourcePath');
        return null;
      }

      final dir = await _getCardImagesDirectory();
      final extension = path.extension(sourcePath);
      final fileName = '$cardId$extension';
      final destinationPath = path.join(dir.path, fileName);

      final destinationFile = await sourceFile.copy(destinationPath);
      debugPrint('✅ [LocalImage] Image saved: $destinationPath');

      return destinationFile.path;
    } catch (e) {
      debugPrint('❌ [LocalImage] Error saving image: $e');
      return null;
    }
  }

  /// Save image from bytes (useful when receiving via Nearby Share)
  Future<String?> saveCardImageFromBytes(
      String cardId, Uint8List imageBytes) async {
    try {
      final dir = await _getCardImagesDirectory();
      final fileName = '$cardId.jpg';
      final destinationPath = path.join(dir.path, fileName);

      final file = File(destinationPath);
      await file.writeAsBytes(imageBytes);
      debugPrint('✅ [LocalImage] Image saved from bytes: $destinationPath');

      return destinationPath;
    } catch (e) {
      debugPrint('❌ [LocalImage] Error saving image from bytes: $e');
      return null;
    }
  }

  /// Get local image path for a card
  Future<String?> getCardImagePath(String cardId) async {
    try {
      final dir = await _getCardImagesDirectory();

      // Check for common image extensions
      final extensions = ['.jpg', '.jpeg', '.png', '.webp'];
      for (final ext in extensions) {
        final filePath = path.join(dir.path, '$cardId$ext');
        final file = File(filePath);
        if (await file.exists()) {
          return filePath;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ [LocalImage] Error getting image path: $e');
      return null;
    }
  }

  /// Read image as bytes for sharing
  Future<Uint8List?> getCardImageBytes(String cardId) async {
    try {
      final imagePath = await getCardImagePath(cardId);
      if (imagePath == null) return null;

      final file = File(imagePath);
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('❌ [LocalImage] Error reading image bytes: $e');
      return null;
    }
  }

  /// Delete card image
  Future<bool> deleteCardImage(String cardId) async {
    try {
      final imagePath = await getCardImagePath(cardId);
      if (imagePath == null) return false;

      final file = File(imagePath);
      await file.delete();
      debugPrint('✅ [LocalImage] Image deleted: $imagePath');
      return true;
    } catch (e) {
      debugPrint('❌ [LocalImage] Error deleting image: $e');
      return false;
    }
  }

  /// Check if card has a local image
  Future<bool> hasCardImage(String cardId) async {
    final imagePath = await getCardImagePath(cardId);
    return imagePath != null;
  }
}
