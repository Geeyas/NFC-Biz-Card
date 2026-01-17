import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cardflow/services/connection_service.dart';
import 'package:cardflow/screens/business_card.dart';
import 'package:cardflow/screens/edit_submission_screen.dart';
import '../widgets/animated_gradient_container.dart';
import '../services/local_image_service.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  _MySubmissionsScreenState createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  bool _showFirstTimeHint = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUser();
    _fetchSubmissions();
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenHint = prefs.getBool('has_seen_my_cards_hint') ?? false;

    if (!hasSeenHint) {
      setState(() {
        _showFirstTimeHint = true;
      });
      // Mark as seen
      await prefs.setBool('has_seen_my_cards_hint', true);
    }
  }

  Future<void> _fetchSubmissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      print('🎯 [MyCards] Current user: ${user?.uid}');
      print('🎯 [MyCards] User display name: ${user?.displayName}');
      if (user != null) {
        String userId = user.uid;

        // Try loading from createdCards folder first (new structure)
        DatabaseReference createdCardsRef = FirebaseDatabase.instance
            .ref('users')
            .child(userId)
            .child('createdCards');

        print('🎯 [MyCards] Loading from: users/$userId/createdCards');
        DatabaseEvent event = await createdCardsRef.once();
        DataSnapshot snapshot = event.snapshot;

        print('🎯 [MyCards] Snapshot exists: ${snapshot.exists}');

        List<Map<String, dynamic>> tempSubmissions = [];

        if (snapshot.exists) {
          print('✅ [MyCards] Found createdCards folder!');
          Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

          data.forEach((key, value) {
            if (value is Map) {
              Map<String, dynamic> submission =
                  Map<String, dynamic>.from(value);
              submission['id'] = key;
              tempSubmissions.add(submission);
            }
          });

          print(
              '✅ [MyCards] Found ${tempSubmissions.length} cards from createdCards');
          tempSubmissions.forEach((submission) {
            print(
                '📝 [MyCards] Card: ${submission['businessName']} - ${submission['email']}');
          });
        } else {
          // Fallback to old structure
          print('⚠️ [MyCards] No createdCards folder, trying old structure...');
          DatabaseReference oldRef =
              FirebaseDatabase.instance.ref('users').child(userId);

          DatabaseEvent oldEvent = await oldRef.once();
          DataSnapshot oldSnapshot = oldEvent.snapshot;

          if (oldSnapshot.exists) {
            Map<dynamic, dynamic> data =
                oldSnapshot.value as Map<dynamic, dynamic>;

            data.forEach((key, value) {
              // Skip special folders and only get card objects
              if (key != 'receivedCards' &&
                  key != 'connections' &&
                  key != 'analytics' &&
                  key != 'profile' &&
                  value is Map) {
                Map<String, dynamic> submission =
                    Map<String, dynamic>.from(value);
                submission['id'] = key;
                tempSubmissions.add(submission);
              }
            });

            print(
                '✅ [MyCards] Found ${tempSubmissions.length} cards from old structure');
            tempSubmissions.forEach((submission) {
              print(
                  '📝 [MyCards] Card: ${submission['businessName']} - ${submission['email']}');
            });
          }
        }

        setState(() {
          _submissions = tempSubmissions;
          _isLoading = false;
        });

        // Show hint after loading if first time and has cards
        if (_showFirstTimeHint && tempSubmissions.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showFirstTimeHintDialog();
            }
          });
        }
      } else {
        print('❌ [MyCards] No user authenticated');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('❌ [MyCards] Error fetching submissions: $e');
    }
  }

  void _showFirstTimeHintDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.purple.shade50,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 48,
                  color: Colors.amber.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to CardFlow!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We\'ve created a sample card using your Google account info to get you started.',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHintRow(Icons.edit,
                        'Edit the card to add your business details'),
                    const SizedBox(height: 8),
                    _buildHintRow(Icons.delete_outline,
                        'Or delete it and create your own from scratch'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Got it!',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteSubmission(String submissionId, String? imageUrl) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Card?', style: GoogleFonts.poppins()),
        content: Text(
          'Are you sure you want to delete this card? This action cannot be undone and will remove all associated connections.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userId = user.uid;

        // Step 1: Delete connections associated with this card
        await _deleteCardConnections(submissionId, userId);

        // Step 2: Try deleting from createdCards folder first (new structure)
        DatabaseReference createdCardRef = FirebaseDatabase.instance
            .ref('users')
            .child(userId)
            .child('createdCards')
            .child(submissionId);

        // Check if card exists in createdCards folder
        DatabaseEvent event = await createdCardRef.once();
        if (event.snapshot.exists) {
          await createdCardRef.remove();
          print('✅ [MyCards] Deleted card from createdCards folder');
        } else {
          // Fallback: delete from old structure
          DatabaseReference oldRef = FirebaseDatabase.instance
              .ref('users')
              .child(userId)
              .child(submissionId);
          await oldRef.remove();
          print('✅ [MyCards] Deleted card from old structure');
        }

        // Step 3: Delete analytics for this card
        await FirebaseDatabase.instance
            .ref('users')
            .child(userId)
            .child('analytics')
            .child('cardStats')
            .child(submissionId)
            .remove();

        // Step 4: Delete image from Firebase Storage if it exists
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(imageUrl).delete();
            print('✅ [MyCards] Deleted image from storage');
          } catch (storageError) {
            print('⚠️ Error deleting image: $storageError');
          }
        }

        // Refresh the submissions list
        _fetchSubmissions();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Card deleted successfully. Associated connections have been removed.'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      print('❌ [MyCards] Error deleting submission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting card: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  /// Delete all connections associated with a specific card
  /// When a card is deleted, all connections made through that card are terminated
  Future<void> _deleteCardConnections(String cardId, String userId) async {
    try {
      print(
          '🔍 [MyCards] Looking for connections associated with card: $cardId');

      // Get all connections from the global connections node
      final connectionsRef = FirebaseDatabase.instance.ref('connections');
      final snapshot = await connectionsRef.get();

      if (!snapshot.exists) {
        print('ℹ️ [MyCards] No connections found in database');
        return;
      }

      final connectionsData = Map<String, dynamic>.from(snapshot.value as Map);
      final username = FirebaseAuth.instance.currentUser?.displayName ??
          FirebaseAuth.instance.currentUser?.email ??
          userId;

      List<String> connectionsToDelete = [];

      // Find connections where this card was used
      connectionsData.forEach((connectionId, connectionValue) {
        if (connectionValue is Map) {
          final conn = Map<String, dynamic>.from(connectionValue);
          // Check if this connection involves the current user and this specific card
          if ((conn['initiatorId'] == userId ||
                  conn['recipientId'] == userId) &&
              conn['cardId'] == cardId) {
            connectionsToDelete.add(connectionId);
          }
        }
      });

      print(
          '📊 [MyCards] Found ${connectionsToDelete.length} connections to delete');

      // Delete each connection and update user connection lists
      for (String connectionId in connectionsToDelete) {
        final conn = Connection.fromMap(
          connectionId,
          connectionsData[connectionId] as Map,
        );

        final otherUserName = conn.getOtherUserName(userId);

        // Delete from global connections
        await connectionsRef.child(connectionId).remove();

        // Delete from current user's connection lists
        await _removeUserConnectionReferences(
            username, otherUserName, conn.status);

        // Delete from other user's connection lists
        await _removeUserConnectionReferences(
            otherUserName, username, conn.status);

        // Mark messages for deletion (optional - keep for 4 days as you mentioned)
        await _scheduleMessageDeletion(connectionId);

        print(
            '✅ [MyCards] Deleted connection: $connectionId with $otherUserName');
      }
    } catch (e) {
      print('❌ [MyCards] Error deleting card connections: $e');
    }
  }

  /// Remove connection references from user's connection lists
  Future<void> _removeUserConnectionReferences(
    String username,
    String otherUserName,
    ConnectionStatus status,
  ) async {
    try {
      final userConnectionsRef = FirebaseDatabase.instance
          .ref('users')
          .child(username)
          .child('connections');

      // Remove from appropriate status folder
      switch (status) {
        case ConnectionStatus.connected:
          await userConnectionsRef.child('connected/$otherUserName').remove();
          break;
        case ConnectionStatus.pending:
          await userConnectionsRef
              .child('pending_received/$otherUserName')
              .remove();
          await userConnectionsRef
              .child('pending_sent/$otherUserName')
              .remove();
          break;
        default:
          break;
      }
    } catch (e) {
      print('⚠️ Error removing connection references: $e');
    }
  }

  /// Schedule message deletion (keep messages for 4 days)
  Future<void> _scheduleMessageDeletion(String connectionId) async {
    try {
      final messagesRef =
          FirebaseDatabase.instance.ref('messages').child(connectionId);

      // Add deletion timestamp (4 days from now)
      final deletionTime = DateTime.now().add(const Duration(days: 4));
      await messagesRef.child('_metadata').set({
        'scheduledDeletion': deletionTime.millisecondsSinceEpoch,
        'reason': 'Card deleted - messages will be removed after 4 days',
      });

      print(
          '📅 [MyCards] Messages scheduled for deletion on: ${deletionTime.toLocal()}');
    } catch (e) {
      print('⚠️ Error scheduling message deletion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'My Cards',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: ClipRRect(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _submissions.isEmpty
                    ? Center(
                        child: Text(
                          'No submissions found. Fill out the form to get started!',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : AnimationLimiter(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _submissions.length,
                          itemBuilder: (context, index) {
                            final submission = _submissions[index];
                            return _buildBusinessCardItem(submission, index);
                          },
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessCardItem(Map<String, dynamic> submission, int index) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                // Horizontal Business Card - Clickable
                InkWell(
                  onTap: () {
                    _viewBusinessCard(submission);
                  },
                  child: Container(
                    height: 190, // Reduced height for more compact card
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _getCardGradientColors(submission),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Background pattern
                          Positioned.fill(
                            child: CustomPaint(
                              painter: CardPatternPainter(),
                            ),
                          ),
                          // Card content
                          Padding(
                            padding: const EdgeInsets.all(
                                16.0), // Reduced from 24 to 16
                            child: Row(
                              children: [
                                // Left side - Logo/Image
                                Container(
                                  width: 70, // Reduced from 80
                                  height: 70, // Reduced from 80
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white.withOpacity(0.2),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: FutureBuilder<String?>(
                                    future: LocalImageService()
                                        .getCardImagePath(submission['id']),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data != null) {
                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.file(
                                            File(snapshot.data!),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.business,
                                                color: Colors.white,
                                                size: 40,
                                              );
                                            },
                                          ),
                                        );
                                      }
                                      // Fallback to network image if exists
                                      else if (submission['imageUrl'] != null &&
                                          submission['imageUrl'].isNotEmpty) {
                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.network(
                                            submission['imageUrl'],
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.business,
                                                color: Colors.white,
                                                size: 40,
                                              );
                                            },
                                          ),
                                        );
                                      }
                                      // Default icon if no image
                                      return const Icon(
                                        Icons.business,
                                        color: Colors.white,
                                        size: 40,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16), // Reduced from 24
                                // Right side - Information
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        submission['businessName'] ??
                                            'Sample Card',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18, // Reduced from 22
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(
                                          height: 4), // Reduced from 6
                                      Text(
                                        submission['personName'] ??
                                            'Sample Person (Delete & create your own)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14, // Reduced from 16
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(
                                          height: 6), // Reduced from 8
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.email_outlined,
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            size: 14, // Reduced from 16
                                          ),
                                          const SizedBox(
                                              width: 6), // Reduced from 8
                                          Expanded(
                                            child: Text(
                                              submission['email'] ??
                                                  'email@example.com',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12, // Reduced from 14
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                          height: 3), // Reduced from 5
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_outlined,
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            size: 14, // Reduced from 16
                                          ),
                                          const SizedBox(
                                              width: 6), // Reduced from 8
                                          Expanded(
                                            child: Text(
                                              submission['contactNumber'] ??
                                                  '+1234567890',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12, // Reduced from 14
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                          height: 3), // Reduced from 5
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.language_outlined,
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            size: 14, // Reduced from 16
                                          ),
                                          const SizedBox(
                                              width: 6), // Reduced from 8
                                          Expanded(
                                            child: Text(
                                              submission['website'] ??
                                                  'www.website.com',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12, // Reduced from 14
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Subtle Action Buttons Row with Glassmorphism effect
                GlassmorphicContainer(
                  width: double.infinity,
                  height: 50,
                  borderRadius: 15,
                  blur: 10,
                  alignment: Alignment.bottomCenter,
                  border: 1,
                  linearGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Edit button
                      _buildSubtleActionButton(
                        icon: Icons.edit_outlined,
                        color: Colors.blue.shade600,
                        onTap: () => _editSubmission(submission),
                      ),
                      const SizedBox(width: 4),
                      // Delete button
                      _buildSubtleActionButton(
                        icon: Icons.delete_outline,
                        color: Colors.red.shade500,
                        onTap: () => _deleteSubmission(
                            submission['id'], submission['imageUrl']),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // New method for subtle action buttons with glassmorphism effect
  Widget _buildSubtleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Tooltip(
            message: icon == Icons.edit_outlined ? 'Edit' : 'Delete',
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  void _startNFCSharing(Map<String, dynamic> submission) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.nfc, color: Colors.green.shade600),
              const SizedBox(width: 10),
              Text(
                'NFC Sharing',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // NFC Animation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated ripple effect
                    TweenAnimationBuilder(
                      duration: const Duration(seconds: 2),
                      tween: Tween<double>(begin: 0.5, end: 1.0),
                      builder: (context, double value, child) {
                        return Container(
                          width: 80 * value,
                          height: 80 * value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.shade200.withOpacity(1 - value),
                          ),
                        );
                      },
                      onEnd: () {
                        // Restart animation
                      },
                    ),
                    Icon(Icons.nfc, size: 40, color: Colors.green.shade600),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Ready to Share!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Hold your device close to another NFC-enabled device to share your business card.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Implement actual NFC sharing here
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'NFC sharing initiated for ${submission['businessName']}'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Start Sharing',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Color> _getCardGradientColors(Map<String, dynamic> submission) {
    try {
      if (submission['themeData'] != null) {
        final themeData = submission['themeData'] as Map<dynamic, dynamic>;

        // Parse gradient colors from hex strings
        if (themeData['gradientColor1'] != null &&
            themeData['gradientColor2'] != null) {
          final color1 = Color(
              int.parse(themeData['gradientColor1'].toString(), radix: 16));
          final color2 = Color(
              int.parse(themeData['gradientColor2'].toString(), radix: 16));
          return [color1, color2];
        }
      }
    } catch (e) {
      print('Error parsing theme colors: $e');
    }

    // Default fallback for old cards or parsing errors
    return [Colors.blue.shade600, Colors.purple.shade700];
  }

  void _viewBusinessCard(Map<String, dynamic> submission) {
    // Convert themeData to proper Map<String, dynamic> if it exists
    Map<String, dynamic>? themeData;
    if (submission['themeData'] != null) {
      try {
        if (submission['themeData'] is Map) {
          themeData = Map<String, dynamic>.from(submission['themeData'] as Map);
        }
      } catch (e) {
        print('Error converting themeData: $e');
        themeData = null;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessCardScreen(
          businessName: submission['businessName'] ?? 'Unknown Business',
          personName: submission['personName'] ?? 'Unknown Person',
          website: submission['website'],
          email: submission['email'] ?? '',
          contactNumber: submission['contactNumber'] ?? '',
          image: submission['imageUrl'],
          themeData: themeData, // Pass converted theme data
          cardId: submission['id'], // Pass card ID for analytics
        ),
      ),
    );
  }

  void _editSubmission(Map<String, dynamic> submission) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSubmissionScreen(
          submissionId: submission['id'],
          initialData: submission,
        ),
      ),
    ).then((_) {
      _fetchSubmissions();
    });
  }
}

// Custom painter for card background pattern
class CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Create a subtle geometric pattern
    for (int i = 0; i < 10; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.8 + i * 10, size.height * 0.2 + i * 5),
        20 + i * 2,
        paint,
      );
    }

    // Add some diagonal lines
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(size.width * 0.7, i * 20.0),
        Offset(size.width * 0.9, i * 20.0 + 40),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
