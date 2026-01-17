import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for tracking and managing analytics events
///
/// This service handles all analytics tracking including:
/// - Card views (when someone opens a card)
/// - Card shares (when someone shares a card)
/// - QR code scans
/// - Contact button clicks (email, phone, website)
class AnalyticsService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID (Firebase UID)
  static String? get _userId {
    final user = _auth.currentUser;
    return user?.uid;
  }

  /// Initialize analytics for a newly created card
  /// Call this when a card is first created
  static Future<void> initializeCardAnalytics({
    required String cardId,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _userId;
      if (uid == null) return;

      // Initialize card-specific analytics in users/{userId}/analytics/cardStats/{cardId}
      await _database.child('users/$uid/analytics/cardStats/$cardId').set({
        'views': 0,
        'shares': 0,
        'scans': 0,
        'emailClicks': 0,
        'phoneClicks': 0,
        'websiteClicks': 0,
        'createdAt': ServerValue.timestamp,
        'lastViewedAt': ServerValue.timestamp,
      });

      print('✅ Analytics initialized for card: $cardId');
    } catch (e) {
      print('❌ Error initializing card analytics: $e');
    }
  }

  /// Track a card view
  /// Call this when BusinessCardScreen opens
  static Future<void> trackCardView({
    required String cardId,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _userId;
      if (uid == null) return;

      final cardAnalyticsRef =
          _database.child('users/$uid/analytics/cardStats/$cardId');
      final globalStatsRef =
          _database.child('users/$uid/analytics/globalStats');

      // Increment card-specific views
      await cardAnalyticsRef.child('views').runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      // Update last viewed timestamp
      await cardAnalyticsRef.child('lastViewedAt').set(ServerValue.timestamp);

      // Increment global total views
      await globalStatsRef.child('totalViews').runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      // Update weekly views (for chart)
      await _updateWeeklyViews(uid);

      print('✅ Card view tracked: $cardId');
    } catch (e) {
      print('❌ Error tracking card view: $e');
    }
  }

  /// Track a card share
  /// Call this when user shares a card via any method (QR, NFC, Nearby, etc.)
  static Future<void> trackCardShare({
    required String cardId,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _userId;
      if (uid == null) return;

      final cardAnalyticsRef =
          _database.child('users/$uid/analytics/cardStats/$cardId');
      final globalStatsRef =
          _database.child('users/$uid/analytics/globalStats');

      // Increment card-specific shares
      await cardAnalyticsRef.child('shares').runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      // Increment global total shares
      await globalStatsRef.child('totalShares').runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      print('✅ Card share tracked: $cardId');
    } catch (e) {
      print('❌ Error tracking card share: $e');
    }
  }

  /// Track a QR code scan
  /// Call this when someone scans a card's QR code
  static Future<void> trackQRScan({
    required String cardId,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _userId;
      if (uid == null) return;

      final cardAnalyticsRef =
          _database.child('users/$uid/analytics/cardStats/$cardId');
      final globalStatsRef =
          _database.child('users/$uid/analytics/globalStats');

      // Increment card-specific scans
      await cardAnalyticsRef.child('scans').runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      // Increment global total scans
      await globalStatsRef.child('totalScans').runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      print('✅ QR scan tracked: $cardId');
    } catch (e) {
      print('❌ Error tracking QR scan: $e');
    }
  }

  /// Track email button click
  static Future<void> trackEmailClick({
    required String cardId,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _userId;
      if (uid == null) return;

      final cardAnalyticsRef =
          _database.child('users/$uid/analytics/cardStats/$cardId');
      final globalStatsRef =
          _database.child('users/$uid/analytics/globalStats');

      // Increment card-specific email clicks
      await cardAnalyticsRef
          .child('emailClicks')
          .runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      // Increment global total email clicks
      await globalStatsRef.child('emailClicks').runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      print('✅ Email click tracked: $cardId');
    } catch (e) {
      print('❌ Error tracking email click: $e');
    }
  }

  /// Track phone button click
  static Future<void> trackPhoneClick({
    required String cardId,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _userId;
      if (uid == null) return;

      final cardAnalyticsRef =
          _database.child('users/$uid/analytics/cardStats/$cardId');
      final globalStatsRef =
          _database.child('users/$uid/analytics/globalStats');

      // Increment card-specific phone clicks
      await cardAnalyticsRef
          .child('phoneClicks')
          .runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      // Increment global total phone clicks
      await globalStatsRef.child('phoneClicks').runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      print('✅ Phone click tracked: $cardId');
    } catch (e) {
      print('❌ Error tracking phone click: $e');
    }
  }

  /// Track website button click
  static Future<void> trackWebsiteClick({
    required String cardId,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _userId;
      if (uid == null) return;

      final cardAnalyticsRef =
          _database.child('users/$uid/analytics/cardStats/$cardId');
      final globalStatsRef =
          _database.child('users/$uid/analytics/globalStats');

      // Increment card-specific website clicks
      await cardAnalyticsRef
          .child('websiteClicks')
          .runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      // Increment global total website clicks
      await globalStatsRef
          .child('websiteClicks')
          .runTransaction((currentValue) {
        final count = (currentValue as int?) ?? 0;
        return Transaction.success(count + 1);
      });

      print('✅ Website click tracked: $cardId');
    } catch (e) {
      print('❌ Error tracking website click: $e');
    }
  }

  /// Update weekly views for the chart
  /// This tracks daily view counts for the last 7 days
  static Future<void> _updateWeeklyViews(String userId) async {
    try {
      final today = DateTime.now();
      final dayOfWeek = today.weekday - 1; // 0 = Monday, 6 = Sunday

      final weeklyViewsRef =
          _database.child('users/$userId/analytics/globalStats/weeklyViews');

      // Get current weekly views array
      final snapshot = await weeklyViewsRef.get();
      List<int> weeklyViews = [0, 0, 0, 0, 0, 0, 0];

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is List) {
          weeklyViews = List<int>.from(data);
        }
      }

      // Increment today's count
      if (dayOfWeek >= 0 && dayOfWeek < 7) {
        weeklyViews[dayOfWeek]++;
      }

      // Save updated array
      await weeklyViewsRef.set(weeklyViews);
    } catch (e) {
      print('❌ Error updating weekly views: $e');
    }
  }

  /// Initialize user analytics node when user signs up
  /// Call this on user registration or first login
  static Future<void> initializeUserAnalytics({String? userId}) async {
    try {
      final uid = userId ?? _userId;
      if (uid == null) return;

      final globalStatsRef =
          _database.child('users/$uid/analytics/globalStats');

      // Check if already initialized
      final snapshot = await globalStatsRef.get();
      if (snapshot.exists) {
        print('ℹ️ User analytics already initialized');
        return;
      }

      // Initialize with default values
      await globalStatsRef.set({
        'totalViews': 0,
        'uniqueViews': 0,
        'totalShares': 0,
        'totalScans': 0,
        'emailClicks': 0,
        'phoneClicks': 0,
        'websiteClicks': 0,
        'viewsGrowth': 0.0,
        'sharesGrowth': 0.0,
        'weeklyViews': [0, 0, 0, 0, 0, 0, 0],
      });

      print('✅ User analytics initialized for user ID: $uid');
    } catch (e) {
      print('❌ Error initializing user analytics: $e');
    }
  }
}
