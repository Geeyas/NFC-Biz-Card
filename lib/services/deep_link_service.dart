import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static const platform = MethodChannel('com.example.ygit_app/deeplink');

  /// Initialize deep link handling
  Future<void> initialize(BuildContext context) async {
    // Set method call handler for deep links
    platform.setMethodCallHandler((call) async {
      if (call.method == 'handleDeepLink') {
        final String? url = call.arguments as String?;
        if (url != null) {
          final uri = Uri.parse(url);
          _handleDeepLink(uri, context);
        }
      }
    });

    // Check for initial deep link
    try {
      final String? initialLink = await platform.invokeMethod('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        final uri = Uri.parse(initialLink);
        _handleDeepLink(uri, context);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri, BuildContext context) async {
    debugPrint('📱 Deep link received: $uri');

    // Check if it's a card sharing link
    if (uri.scheme == 'cardflow' && uri.host == 'share') {
      final userName = uri.queryParameters['user'];
      final cardId = uri.queryParameters['cardId'];

      if (userName != null && cardId != null) {
        debugPrint('🔗 Fetching card: $cardId from user: $userName');
        await _handleCardSharing(context, userName, cardId);
      } else {
        debugPrint('❌ Missing parameters in deep link');
        _showError(context, 'Invalid card link');
      }
    }
  }

  /// Fetch card data and save to received cards
  Future<void> _handleCardSharing(
    BuildContext context,
    String userName,
    String cardId,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showError(context, 'Please login to receive cards');
        return;
      }

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Fetch card data from sender's cards (directly under user, no 'cards' child)
      debugPrint('🔍 Looking for card at: users/$userName/$cardId');
      final cardRef = FirebaseDatabase.instance
          .ref('users')
          .child(userName) // Use original username with spaces
          .child(cardId);

      final snapshot = await cardRef.get();

      if (!snapshot.exists) {
        debugPrint('❌ Card not found at: users/$userName/$cardId');
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          _showError(context, 'Card not found');
        }
        return;
      }

      final cardData = Map<String, dynamic>.from(snapshot.value as Map);
      debugPrint('✅ Card data found: ${cardData['businessName']}');

      // Try to get sender's actual userId and photo URL
      // The userName in deep link is the display name, we need to get the userId
      String? sharedByUserId;
      String? sharedByPhoto;

      try {
        // Get list of all users to find the one with matching display name
        final usersRef = FirebaseDatabase.instance.ref('users');
        final usersSnapshot = await usersRef.get();

        if (usersSnapshot.exists) {
          final users = usersSnapshot.value as Map<dynamic, dynamic>;

          // Find the user whose display name matches the userName
          for (var entry in users.entries) {
            final userKey = entry.key as String;
            final userData = entry.value;

            // Check if this user's key matches the userName (could be username or uid)
            if (userKey == userName) {
              // For now, we'll use the database key as userId
              // This works because cards are stored under users/{userId}/
              sharedByUserId = userKey;

              // Try to get photo from profile if stored
              if (userData is Map && userData['profile'] != null) {
                sharedByPhoto = userData['profile']['photoURL'] as String?;
              }
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Could not fetch sender userId: $e');
      }

      // Fallback: use userName as userId if not found (backward compatibility)
      sharedByUserId = sharedByUserId ?? userName;

      // Fallback to card image if no profile photo found
      sharedByPhoto = sharedByPhoto ?? cardData['imageUrl'] as String?;

      // Save to current user's received cards using ORIGINAL card ID
      // Use displayName for database path (matching existing structure)
      final currentUsername =
          currentUser.displayName ?? currentUser.email ?? currentUser.uid;
      final receivedCardsRef = FirebaseDatabase.instance
          .ref('users')
          .child(currentUsername)
          .child('receivedCards')
          .child(cardId); // Use ORIGINAL card ID instead of push()

      await receivedCardsRef.set({
        ...cardData,
        'receivedAt': ServerValue.timestamp,
        'sharedBy': sharedByUserId, // Use actual userId, not display name!
        'sharedByUsername': userName, // Store display name separately
        'sharedByPhoto': sharedByPhoto, // Add sender's photo
        'originalCardId': cardId, // Store original card ID for analytics
      });

      debugPrint('✅ Card saved/updated in received cards with ID: $cardId');

      debugPrint('✅ Card saved to received cards');

      // Close loading and show card
      if (context.mounted) {
        Navigator.pop(context); // Close loading

        // Navigate to the business card screen
        Navigator.pushNamed(
          context,
          '/business-card',
          arguments: {
            'businessName': cardData['businessName'] ?? '',
            'personName': cardData['personName'] ?? '',
            'website': cardData['website'] ?? '',
            'email': cardData['email'] ?? '',
            'contactNumber': cardData['contactNumber'] ?? '',
            'imageUrl':
                cardData['imageUrl'] ?? '', // Use 'imageUrl' not 'image'
            'themeId': cardData['themeId'],
            'themeData': cardData['themeData'],
            'cardId': cardId,
          },
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Card received and saved to My Network!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling card sharing: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showError(context, 'Failed to receive card: $e');
      }
    }
  }

  /// Show error message
  void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Dispose the service
  void dispose() {
    // Clean up if needed
  }
}
