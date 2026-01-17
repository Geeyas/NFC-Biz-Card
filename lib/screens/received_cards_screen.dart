import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/animated_gradient_container.dart';
import '../services/analytics_service.dart';
import '../services/connection_service.dart';
import '../screens/chat_screen.dart';
import 'business_card.dart';

class ReceivedCardsScreen extends StatefulWidget {
  const ReceivedCardsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ReceivedCardsScreenState createState() => _ReceivedCardsScreenState();
}

class _ReceivedCardsScreenState extends State<ReceivedCardsScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final User? user = FirebaseAuth.instance.currentUser;
  final ConnectionService _connectionService = ConnectionService();

  List<Map<String, dynamic>> _receivedCards = [];
  bool _isLoading = true;
  Map<String, ConnectionStatus> _connectionStatuses = {}; // userId -> status

  @override
  void initState() {
    super.initState();
    _loadReceivedCards();
  }

  Future<void> _loadConnectionStatus(String userId) async {
    if (userId.isEmpty) return;

    final status = await _connectionService.getConnectionStatus(userId);
    if (status != null) {
      setState(() {
        _connectionStatuses[userId] = status;
      });
    }
  }

  Future<void> _sendConnectionRequest(
      String userId, String userName, String cardId) async {
    // Find the card to get the CARD's name and photo (not user's Firebase profile)
    final card = _receivedCards.firstWhere(
      (c) => c['id'] == cardId,
      orElse: () => <String, dynamic>{},
    );

    // Get name from card's businessName or personName (this is what appears on the card)
    final cardBusinessName = card['businessName'] as String?;
    final cardPersonName = card['personName'] as String?;
    final recipientName = cardBusinessName ?? cardPersonName ?? userName;

    // Get photo from card's imageUrl (the card image itself)
    final recipientPhoto = card['imageUrl'] as String?;

    debugPrint('🔍 [SendConnectionRequest] Using card data:');
    debugPrint('   Card ID: $cardId');
    debugPrint('   Business Name: $cardBusinessName');
    debugPrint('   Person Name: $cardPersonName');
    debugPrint('   Final Name: $recipientName');
    debugPrint('   Photo URL: $recipientPhoto');

    final success = await _connectionService.sendConnectionRequest(
      recipientId: userId,
      recipientName: recipientName,
      recipientPhoto: recipientPhoto,
      cardId: cardId,
      shareMethod: 'my_network',
      note: 'Let\'s connect!',
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to $recipientName!'),
          backgroundColor: const Color(0xFF2ebf91),
        ),
      );
      await _loadConnectionStatus(userId);
    }
  }

  Future<void> _openChat(
      String userId, String userName, String? userPhoto) async {
    // Get connection ID
    final connections = await _connectionService.getMyConnections().first;
    final connection = connections.firstWhere(
      (c) => c.getOtherUserId(_connectionService.currentUserId!) == userId,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(connection: connection),
        ),
      );
    }
  }

  Future<void> _loadReceivedCards() async {
    if (user == null) return;

    try {
      // Use displayName for database path (matching your existing structure)
      final snapshot = await _database
          .child('users')
          .child(user!.displayName ?? user!.uid)
          .child('receivedCards')
          .get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> tempCards = [];

        data.forEach((key, value) {
          Map<String, dynamic> card = Map<String, dynamic>.from(value);
          card['id'] = key;
          tempCards.add(card);
        });

        // Sort by timestamp (newest first)
        tempCards.sort((a, b) {
          int timestampA = a['receivedAt'] ?? 0;
          int timestampB = b['receivedAt'] ?? 0;
          return timestampB.compareTo(timestampA);
        });

        setState(() {
          _receivedCards = tempCards;
          _isLoading = false;
        });
      } else {
        setState(() {
          _receivedCards = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading received cards: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back, color: Colors.grey.shade800),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Network',
          style: GoogleFonts.poppins(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : _receivedCards.isEmpty
                  ? _buildEmptyState()
                  : _buildCardsList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: GlassmorphicContainer(
          width: double.infinity,
          height: 400,
          borderRadius: 25,
          blur: 30,
          alignment: Alignment.center,
          border: 2.5,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.grey.shade50.withOpacity(0.15),
            ],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.7),
              Colors.grey.shade300.withOpacity(0.4),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFe67e22).withOpacity(0.75),
                      const Color(0xFFe74c3c).withOpacity(0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFe67e22).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.people_outline,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'No Cards Yet',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Cards shared with you will appear here',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardsList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.of(context).size.width * 0.045;

        return Padding(
          padding: EdgeInsets.all(padding.clamp(16.0, 20.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_receivedCards.length} ${_receivedCards.length == 1 ? 'Card' : 'Cards'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: _receivedCards.length,
                  itemBuilder: (context, index) {
                    return _buildCardItem(_receivedCards[index], index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () => _viewCard(card),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: card['imageUrl'] != null &&
                          card['imageUrl'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            card['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 15),

                // Card Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card['personName'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        card['businessName'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _getReceivedTimeAgo(card['receivedAt']),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.visibility,
                                color: Color(0xFF667eea)),
                            onPressed: () => _viewCard(card),
                            iconSize: 20,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteCard(card['id']),
                            iconSize: 20,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Connection Button
                    _buildConnectionButton(card),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionButton(Map<String, dynamic> card) {
    final userId = card['sharedBy'] ?? '';
    final userName = card['personName'] ?? 'User';
    final cardId = card['id'] ?? '';

    // Load status if not already loaded
    if (userId.isNotEmpty && !_connectionStatuses.containsKey(userId)) {
      _loadConnectionStatus(userId);
    }

    final status = _connectionStatuses[userId];

    // If no status yet, show Connect button (will load status in background)
    if (status == null) {
      return SizedBox(
        width: 110,
        child: ElevatedButton.icon(
          onPressed: () => _sendConnectionRequest(userId, userName, cardId),
          icon: const Icon(Icons.person_add, size: 14),
          label: const Text('Connect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    switch (status) {
      case ConnectionStatus.connected:
        return SizedBox(
          width: 110,
          child: ElevatedButton.icon(
            onPressed: () => _openChat(
              userId,
              userName,
              card['imageUrl'],
            ),
            icon: const Icon(Icons.chat_bubble, size: 14),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ebf91),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );

      case ConnectionStatus.pending:
        return SizedBox(
          width: 110,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_empty, size: 14),
            label: const Text('Pending'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );

      case ConnectionStatus.declined:
      case ConnectionStatus.blocked:
        // For declined/blocked, show Connect button again
        return SizedBox(
          width: 110,
          child: ElevatedButton.icon(
            onPressed: () => _sendConnectionRequest(userId, userName, cardId),
            icon: const Icon(Icons.person_add, size: 14),
            label: const Text('Connect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
    }
  }

  String _getReceivedTimeAgo(int? timestamp) {
    if (timestamp == null) return 'Recently';

    final now = DateTime.now();
    final receivedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(receivedDate);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _viewCard(Map<String, dynamic> card) async {
    // Track card view for the original owner
    final sharedBy = card['sharedBy'];
    final originalCardId = card['originalCardId'];

    if (sharedBy != null && originalCardId != null) {
      print('📊 Tracking view: Card $originalCardId by $sharedBy');
      await AnalyticsService.trackCardView(
        cardId: originalCardId,
        userId: sharedBy, // Track for OWNER, not viewer
      );
    }

    // Convert themeData if it exists
    Map<String, dynamic>? themeData;
    if (card['themeData'] != null) {
      try {
        if (card['themeData'] is Map) {
          themeData = Map<String, dynamic>.from(card['themeData'] as Map);
        }
      } catch (e) {
        print('Error converting themeData: $e');
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessCardScreen(
          businessName: card['businessName'] ?? 'Unknown Business',
          personName: card['personName'] ?? 'Unknown Person',
          website: card['website'],
          email: card['email'] ?? '',
          contactNumber: card['contactNumber'] ?? '',
          image: card['imageUrl'],
          themeData: themeData,
          cardId: originalCardId, // Use original card ID for analytics
          ownerUsername: sharedBy, // Pass owner username for button tracking
        ),
      ),
    );
  }

  Future<void> _deleteCard(String cardId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Card?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove this card from your network?',
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

    if (confirmed == true && user != null) {
      try {
        // Use displayName for database path (matching your existing structure)
        await _database
            .child('users')
            .child(user!.displayName ?? user!.uid)
            .child('receivedCards')
            .child(cardId)
            .remove();

        setState(() {
          _receivedCards.removeWhere((card) => card['id'] == cardId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card removed', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error deleting card: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to delete card', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
