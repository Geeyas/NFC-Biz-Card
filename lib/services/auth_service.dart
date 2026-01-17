import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  User? get currentUser => _auth.currentUser;

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User canceled sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      // Initialize user profile in database if new user
      if (user != null) {
        await _initializeUserProfile(user);
      }

      notifyListeners();
      return user;
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      return null;
    }
  }

  // Initialize user profile in database
  Future<void> _initializeUserProfile(User user) async {
    try {
      final userRef = _database.child('users').child(user.uid);
      final snapshot = await userRef.child('profile').once();

      // Only create profile if it doesn't exist
      if (snapshot.snapshot.value == null) {
        await userRef.child('profile').set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'createdAt': ServerValue.timestamp,
        });
        debugPrint('✅ [Auth] User profile created for ${user.uid}');
      } else {
        debugPrint('✅ [Auth] User profile already exists for ${user.uid}');
      }

      // Always check if user needs a sample card (even for existing users)
      await _createSampleCard(user);
    } catch (e) {
      debugPrint('❌ [Auth] Error initializing user profile: $e');
    }
  }

  // Create sample card with user's Google account information
  Future<void> _createSampleCard(User user) async {
    try {
      debugPrint('🔍 [Auth] Checking if sample card needed for ${user.uid}');
      final userRef = _database.child('users').child(user.uid);
      final createdCardsRef = userRef.child('createdCards');

      // Check if user already has cards
      final cardsSnapshot = await createdCardsRef.once();
      debugPrint(
          '🔍 [Auth] Cards snapshot value: ${cardsSnapshot.snapshot.value}');

      if (cardsSnapshot.snapshot.value != null) {
        debugPrint('✅ [Auth] User already has cards, skipping sample');
        return;
      }

      debugPrint('🔨 [Auth] Creating sample card...');

      // Create a sample card with user's actual info
      final sampleCardRef = createdCardsRef.push();
      final cardId = sampleCardRef.key!;

      debugPrint('🔨 [Auth] Card ID: $cardId');

      // Extract first name for businessName
      final fullName = user.displayName ?? 'Your Name';
      final firstName = fullName.split(' ').first;

      debugPrint('🔨 [Auth] Creating card for: $fullName ($firstName)');

      await sampleCardRef.set({
        'id': cardId,
        'personName': fullName,
        'businessName': '$firstName\'s Business',
        'email': user.email ?? '',
        'contactNumber': '',
        'website': '',
        'timestamp': ServerValue.timestamp,
        'themeData': {
          'themeId': 'professional_blue',
          'gradientColor1': 'ff667eea',
          'gradientColor2': 'ff764ba2',
          'textColor': 'ffffffff',
          'accentColor': 'ff667eea',
          'fontFamily': 'Poppins',
          'borderRadius': 20.0,
          'hasGlassEffect': true,
        },
      });

      debugPrint('✅ [Auth] Sample card created with user info for ${user.uid}');
    } catch (e) {
      debugPrint('❌ [Auth] Error creating sample card: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Error during sign-out: $e');
    }
  }

  // Listen to auth state changes
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
