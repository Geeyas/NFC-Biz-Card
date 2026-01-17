import 'package:firebase_database/firebase_database.dart';
import 'package:cardflow/services/analytics_service.dart';
import 'package:cardflow/services/local_image_service.dart';

class FirestoreService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final LocalImageService _localImageService = LocalImageService();

  /// Submit user data to Realtime Database
  /// Returns the generated card ID
  Future<String> submitUserData({
    required String userId,
    required Map<String, dynamic> userData,
    String? imagePath, // Optional local image path
  }) async {
    try {
      // Database reference for the logged-in user (using Firebase UID)
      DatabaseReference userRef = _database.ref().child('users').child(userId);

      // Prepare data payload
      final dataPayload = {
        ...userData,
        'timestamp': ServerValue.timestamp,
      };

      // Save user data in Realtime Database under createdCards folder
      final cardRef = userRef.child('createdCards').push();
      await cardRef.set(dataPayload);

      final cardId = cardRef.key!;
      print('✅ Card created with ID: $cardId');

      // Save image locally if provided
      if (imagePath != null && imagePath.isNotEmpty) {
        final localPath =
            await _localImageService.saveCardImage(cardId, imagePath);
        if (localPath != null) {
          print('✅ Image saved locally: $localPath');
        }
      }

      // Initialize analytics for this card
      await AnalyticsService.initializeCardAnalytics(
        cardId: cardId,
        userId: userId,
      );

      return cardId;
    } catch (e) {
      throw Exception('Error creating card: $e');
    }
  }
}
