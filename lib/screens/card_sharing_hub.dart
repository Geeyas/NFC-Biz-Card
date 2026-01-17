import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import '../widgets/animated_gradient_container.dart';
import '../services/nearby_share_service.dart';
import '../services/analytics_service.dart';
import '../services/local_image_service.dart';
import 'business_card.dart';

class CardSharingHub extends StatefulWidget {
  const CardSharingHub({Key? key}) : super(key: key);

  @override
  State<CardSharingHub> createState() => _CardSharingHubState();
}

class _CardSharingHubState extends State<CardSharingHub>
    with TickerProviderStateMixin {
  String _selectedCardId = '';
  String _selectedCardTitle = 'No Card Selected';
  List<Map<String, dynamic>> _myCards = [];
  bool _isLoadingCards = true;
  String? _receivedImagePath; // Temporary storage for received image

  // Nearby Share Service
  final NearbyShareService _nearbyShare = NearbyShareService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _loadMyCards();
    _initializeAnimations();
    _setupNearbyShareCallbacks();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Ripple animation for nearby share
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleController.repeat();
  }

  void _setupNearbyShareCallbacks() {
    _nearbyShare.onDataReceived = (String cardData) {
      debugPrint('✅ Card data received via Nearby Share');
      Navigator.pop(context); // Close "Receiving..." dialog
      Map<String, dynamic> receivedCard = _decodeCardData(cardData);
      _showReceivedCardDialog(receivedCard);
    };

    _nearbyShare.onImageReceived = (String imagePath) async {
      debugPrint('📸 Image received: $imagePath');
      // Store temporarily - will be copied when card is saved
      _receivedImagePath = imagePath;
    };

    _nearbyShare.onConnectionSuccess = () {
      debugPrint('✅ Nearby Share connection established');
      // Show success animation
      if (mounted) {
        // Close the "Sharing" or "Receiving" dialog first
        Navigator.pop(context);
        // Show success snackbar
        _showSuccessSnackbar('Card shared successfully!');
      }
    };

    _nearbyShare.onError = (String error) {
      debugPrint('❌ Nearby Share error: $error');
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showErrorSnackbar(error);
      }
    };

    _nearbyShare.onDisconnected = () {
      debugPrint('🔌 Nearby Share disconnected');
    };
  }

  Future<void> _loadMyCards() async {
    debugPrint('🎯 [CardSharingHub] _loadMyCards() called');
    setState(() {
      _isLoadingCards = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userId = user.uid;
        debugPrint('📍 [CardSharingHub] User ID: $userId');

        // Try loading from createdCards folder first (new structure)
        DatabaseReference createdCardsRef = FirebaseDatabase.instance
            .ref('users')
            .child(userId)
            .child('createdCards');

        debugPrint(
            '📍 [CardSharingHub] Loading from: users/$userId/createdCards');
        DatabaseEvent event = await createdCardsRef.once();
        DataSnapshot snapshot = event.snapshot;
        debugPrint('📍 [CardSharingHub] Snapshot exists: ${snapshot.exists}');
        debugPrint('📍 [CardSharingHub] Snapshot exists: ${snapshot.exists}');

        List<Map<String, dynamic>> tempCards = [];

        if (snapshot.exists) {
          debugPrint('✅ [CardSharingHub] Found createdCards folder!');
          // New structure: cards are in createdCards folder
          Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
          debugPrint('📊 [CardSharingHub] Data keys: ${data.keys.toList()}');

          data.forEach((key, value) {
            debugPrint('🔍 [CardSharingHub] Processing card: $key');
            if (value is Map) {
              Map<String, dynamic> card = Map<String, dynamic>.from(value);
              card['id'] = key;

              debugPrint(
                  '📝 [CardSharingHub] Card data: ${card.keys.toList()}');
              debugPrint(
                  '📝 [CardSharingHub] businessName: ${card['businessName']}');
              debugPrint(
                  '📝 [CardSharingHub] personName: ${card['personName']}');
              debugPrint('📝 [CardSharingHub] email: ${card['email']}');

              // Ensure themeData is properly converted
              if (card['themeData'] != null && card['themeData'] is Map) {
                card['themeData'] =
                    Map<String, dynamic>.from(card['themeData']);
                debugPrint('✅ Loaded themeData for card: $key');
              } else {
                debugPrint('⚠️ No themeData found for card: $key');
              }

              tempCards.add(card);
            }
          });
          debugPrint(
              '✅ Loaded ${tempCards.length} cards from createdCards folder');
        } else {
          // Fallback to old structure: cards directly under username
          debugPrint('⚠️ No createdCards folder, trying old structure...');
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
                Map<String, dynamic> card = Map<String, dynamic>.from(value);
                card['id'] = key;

                // Ensure themeData is properly converted
                if (card['themeData'] != null && card['themeData'] is Map) {
                  card['themeData'] =
                      Map<String, dynamic>.from(card['themeData']);
                  debugPrint('✅ Loaded themeData for card: $key');
                } else {
                  debugPrint('⚠️ No themeData found for card: $key');
                }

                tempCards.add(card);
              }
            });
            debugPrint('✅ Loaded ${tempCards.length} cards from old structure');
          }
        }

        debugPrint(
            '🎯 [CardSharingHub] Final tempCards count: ${tempCards.length}');
        setState(() {
          _myCards = tempCards;
          if (tempCards.isNotEmpty) {
            _selectedCardId = tempCards[0]['id'];
            _selectedCardTitle = tempCards[0]['businessName'] ?? 'Card';
            debugPrint(
                '🎯 [CardSharingHub] Selected card: $_selectedCardId - $_selectedCardTitle');
          } else {
            debugPrint('⚠️ [CardSharingHub] No cards found!');
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [CardSharingHub] Error loading cards: $e');
    } finally {
      setState(() {
        _isLoadingCards = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _nearbyShare.stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Send & Receive Cards',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          top: false,
          child: _isLoadingCards
              ? const Center(child: CircularProgressIndicator())
              : _myCards.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top:
                            MediaQuery.of(context).padding.top + kToolbarHeight,
                        left: 20,
                        right: 20,
                        bottom: 30, // Bottom padding for scrollable content
                      ),
                      child: AnimationLimiter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 600),
                            childAnimationBuilder: (widget) => SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                              // Card Selector
                              _buildCardSelector(),
                              const SizedBox(height: 20),

                              // Sharing Methods Title
                              Text(
                                'Choose Sharing Method',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade800,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // QR Code Section
                              _buildSectionHeader(
                                icon: Icons.qr_code_2,
                                title: 'QR Code',
                                subtitle: 'Quick & contactless',
                                gradientColors: [
                                  const Color(0xFF667eea),
                                  const Color(0xFF764ba2),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildGroupedMethodsCard(
                                methods: [
                                  {
                                    'icon': Icons.qr_code_2,
                                    'title': 'Show My QR',
                                    'subtitle': 'Let others scan',
                                    'onTap': _showQrCodeDialog,
                                  },
                                  {
                                    'icon': Icons.qr_code_scanner,
                                    'title': 'Scan QR Code',
                                    'subtitle': 'Scan to receive',
                                    'onTap': _scanQrCode,
                                  },
                                  {
                                    'icon': Icons.image,
                                    'title': 'Import QR Image',
                                    'subtitle': 'From gallery',
                                    'onTap': _importQrFromGallery,
                                  },
                                ],
                                gradientColors: [
                                  const Color(0xFF667eea),
                                  const Color(0xFF764ba2),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Nearby Share Section (Premium Feature)
                              _buildSectionHeader(
                                icon: Icons.wifi_tethering,
                                title: 'Nearby Share',
                                subtitle: 'Bring phones close together',
                                gradientColors: [
                                  const Color(0xFFf093fb),
                                  const Color(0xFFf5576c),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildGroupedMethodsCard(
                                methods: [
                                  {
                                    'icon': Icons.wifi_tethering,
                                    'title': 'Share Nearby',
                                    'subtitle': 'Send card instantly',
                                    'onTap': _shareViaNearby,
                                  },
                                  {
                                    'icon': Icons.phonelink_ring,
                                    'title': 'Receive Nearby',
                                    'subtitle': 'Get card instantly',
                                    'onTap': _receiveViaNearby,
                                  },
                                ],
                                gradientColors: [
                                  const Color(0xFFf093fb),
                                  const Color(0xFFf5576c),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Share Link Section
                              _buildSectionHeader(
                                icon: Icons.share,
                                title: 'Digital Share',
                                subtitle: 'Copy link for apps',
                                gradientColors: [
                                  const Color(0xFF2ebf91),
                                  const Color(0xFF8360c3),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildShareLinkCard(),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'No Cards to Share',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create a business card first',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              'Create Card',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSelector() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 90,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.2),
        ],
      ),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card, color: Colors.white),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Card',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _selectedCardTitle,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade800,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              onSelected: (String cardId) {
                final card = _myCards.firstWhere((c) => c['id'] == cardId);
                setState(() {
                  _selectedCardId = cardId;
                  _selectedCardTitle = card['businessName'] ?? 'Card';
                });
              },
              itemBuilder: (BuildContext context) {
                return _myCards.map((card) {
                  return PopupMenuItem<String>(
                    value: card['id'],
                    child: Text(
                      card['businessName'] ?? 'Unnamed Card',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }).toList();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 90,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(isDisabled ? 0.15 : 0.25),
            Colors.white.withOpacity(isDisabled ? 0.1 : 0.15),
          ],
        ),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.2),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: isDisabled
                            ? Colors.grey.shade500
                            : Colors.grey.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    bool isDisabled = false,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color:
                      isDisabled ? Colors.grey.shade500 : Colors.grey.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedMethodsCard({
    required List<Map<String, dynamic>> methods,
    required List<Color> gradientColors,
    bool isDisabled = false,
  }) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: (methods.length * 77.0) + (methods.length - 1),
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(isDisabled ? 0.15 : 0.3),
          Colors.white.withOpacity(isDisabled ? 0.1 : 0.2),
        ],
      ),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
        ],
      ),
      child: Column(
        children: List.generate(methods.length, (index) {
          final method = methods[index];
          return Column(
            children: [
              _buildMethodItem(
                icon: method['icon'] as IconData,
                title: method['title'] as String,
                subtitle: method['subtitle'] as String,
                onTap: method['onTap'] as VoidCallback,
                gradientColors: gradientColors,
                isDisabled: isDisabled,
              ),
              if (index < methods.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: Colors.grey.shade300.withOpacity(0.5),
                    height: 1,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMethodItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required List<Color> gradientColors,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDisabled
                      ? [Colors.grey.shade400, Colors.grey.shade300]
                      : gradientColors,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: isDisabled
                          ? Colors.grey.shade500
                          : Colors.grey.shade800,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade500,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareLinkCard() {
    return GestureDetector(
      onTap: _copyShareLink,
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 90,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.2),
          ],
        ),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.2),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2ebf91), Color(0xFF8360c3)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2ebf91).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.link,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Copy Share Link',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade800,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Share via messaging apps',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2ebf91), Color(0xFF8360c3)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.copy,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Copy',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrCodeDialog() {
    if (_selectedCardId.isEmpty) {
      _showErrorSnackbar('Please select a card first');
      return;
    }

    final selectedCard =
        _myCards.firstWhere((card) => card['id'] == _selectedCardId);
    final cardDataString = _encodeCardData(selectedCard);

    // Track QR code share analytics (displaying QR counts as sharing)
    AnalyticsService.trackCardShare(cardId: _selectedCardId);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive sizing based on screen dimensions
            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;

            // Calculate responsive sizes
            final dialogWidth = (screenWidth * 0.85).clamp(280.0, 380.0);
            final dialogPadding = (screenWidth * 0.05).clamp(16.0, 25.0);
            final iconSize = (screenWidth * 0.12).clamp(50.0, 60.0);
            final titleFontSize = (screenWidth * 0.055).clamp(20.0, 24.0);
            final subtitleFontSize = (screenWidth * 0.032).clamp(12.0, 14.0);
            final qrSize = (screenWidth * 0.45).clamp(160.0, 220.0);
            final qrPadding = (qrSize * 0.1).clamp(15.0, 20.0);
            final buttonPadding = (screenHeight * 0.018).clamp(12.0, 15.0);
            final spacing1 = (screenHeight * 0.02).clamp(12.0, 20.0);
            final spacing2 = (screenHeight * 0.012).clamp(8.0, 10.0);
            final spacing3 = (screenHeight * 0.025).clamp(15.0, 25.0);
            final spacing4 = (screenHeight * 0.03).clamp(20.0, 35.0);

            // Calculate total height based on components
            final dialogHeight = (iconSize +
                    spacing1 +
                    titleFontSize +
                    spacing2 +
                    (subtitleFontSize * 2) +
                    spacing3 +
                    qrSize +
                    (qrPadding * 2) +
                    spacing4 +
                    buttonPadding * 2 +
                    16 +
                    dialogPadding * 2 +
                    20)
                .clamp(400.0, screenHeight * 0.85);

            return GlassmorphicContainer(
              width: dialogWidth,
              height: dialogHeight,
              borderRadius: 25,
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.8),
                ],
              ),
              borderGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.2),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(dialogPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.qr_code_2,
                          color: Colors.white,
                          size: iconSize * 0.58,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing1),
                    Text(
                      'Scan to Receive',
                      style: GoogleFonts.poppins(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: spacing2),
                    Text(
                      _selectedCardTitle,
                      style: GoogleFonts.poppins(
                        fontSize: subtitleFontSize,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing3),
                    Container(
                      padding: EdgeInsets.all(qrPadding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: cardDataString,
                        version: QrVersions.auto,
                        size: qrSize,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: spacing4),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _shareQrCodeAsImage();
                            },
                            icon: const Icon(Icons.share, size: 18),
                            label: Text(
                              'Share QR',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: subtitleFontSize + 2,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2ebf91),
                              foregroundColor: Colors.white,
                              padding:
                                  EdgeInsets.symmetric(vertical: buttonPadding),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              padding:
                                  EdgeInsets.symmetric(vertical: buttonPadding),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: subtitleFontSize + 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _scanQrCode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QrScannerScreen(
          onCardReceived: (cardData) {
            _showReceivedCardDialog(cardData);
          },
        ),
      ),
    );
  }

  /// Import QR code from gallery
  Future<void> _importQrFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        debugPrint('No image selected');
        return;
      }

      debugPrint('\ud83d\uddbc\ufe0f Processing QR code image: ${image.path}');

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Reading QR Code...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Read and decode QR code from image
      final bytes = await image.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        Navigator.pop(context);
        _showErrorSnackbar('Failed to read image');
        return;
      }

      // Try to decode QR code from the image
      try {
        // Convert image to luminance source for zxing
        final width = decodedImage.width;
        final height = decodedImage.height;
        final bytes = <int>[];

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final pixel = decodedImage.getPixel(x, y);
            // Convert to grayscale
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            final gray = ((r + g + b) / 3).round();
            bytes.add(gray);
          }
        }

        // Convert List<int> to Int32List
        final int32Bytes = Int32List.fromList(bytes);
        final source = RGBLuminanceSource(width, height, int32Bytes);
        final bitmap = BinaryBitmap(HybridBinarizer(source));
        final reader = QRCodeReader();
        final result = reader.decode(bitmap);

        if (result != null && result.text.isNotEmpty) {
          debugPrint('✅ QR Code decoded: ${result.text}');

          // Parse the card data from QR code
          final cardData = _decodeCardData(result.text);

          Navigator.pop(context);

          if (cardData.isNotEmpty) {
            // Show the received card dialog
            _showReceivedCardDialog(cardData);
          } else {
            _showErrorSnackbar('Invalid QR code format');
          }
        } else {
          Navigator.pop(context);
          _showErrorSnackbar('No QR code found in image');
        }
      } catch (e) {
        debugPrint('❌ QR decode error: $e');
        Navigator.pop(context);
        _showErrorSnackbar('Failed to decode QR code');
      }
    } catch (e) {
      debugPrint('❌ Error importing QR: $e');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackbar('Failed to import QR code: $e');
    }
  }

  /// Share QR code as a beautifully designed image
  Future<void> _shareQrCodeAsImage() async {
    try {
      if (_selectedCardId.isEmpty) {
        _showErrorSnackbar('Please select a card first');
        return;
      }

      final selectedCard =
          _myCards.firstWhere((card) => card['id'] == _selectedCardId);
      final cardDataString = _encodeCardData(selectedCard);

      debugPrint('📸 Generating QR code image...');

      // Generate QR code image
      final qrValidationResult = QrValidator.validate(
        data: cardDataString,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );

        // Create a picture with branded design
        final pictureRecorder = ui.PictureRecorder();
        final canvas = Canvas(pictureRecorder);

        // Canvas size (1200x1600 for good quality)
        const imageSize = 1200.0;
        const imageHeight = 1600.0;
        const qrSize = 800.0;
        const padding = 80.0;

        // Background gradient
        final gradientPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ).createShader(const Rect.fromLTWH(0, 0, imageSize, imageHeight));

        canvas.drawRect(
          const Rect.fromLTWH(0, 0, imageSize, imageHeight),
          gradientPaint,
        );

        // White card background for QR
        final cardPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        final cardRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(padding, 200, imageSize - (padding * 2), 1100),
          const Radius.circular(40),
        );

        // Draw shadow first
        final shadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
        canvas.drawRRect(
          cardRect.shift(const Offset(0, 15)),
          shadowPaint,
        );

        canvas.drawRRect(cardRect, cardPaint);

        // Draw app title
        final titlePainter = TextPainter(
          text: TextSpan(
            text: 'CardFlow',
            style: GoogleFonts.poppins(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF667eea),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        titlePainter.layout();
        titlePainter.paint(
          canvas,
          Offset((imageSize - titlePainter.width) / 2, 250),
        );

        // Draw QR code centered
        const qrTop = 380.0;
        canvas.save();
        canvas.translate((imageSize - qrSize) / 2, qrTop);
        painter.paint(
          canvas,
          const Size(qrSize, qrSize),
        );
        canvas.restore();

        // Draw card info
        final cardNamePainter = TextPainter(
          text: TextSpan(
            text: selectedCard['businessName'] ?? 'Business Card',
            style: GoogleFonts.poppins(
              fontSize: 44,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        cardNamePainter.layout(maxWidth: imageSize - 200);
        cardNamePainter.paint(
          canvas,
          Offset((imageSize - cardNamePainter.width) / 2, 1230),
        );

        // Draw scan instruction
        final instructionPainter = TextPainter(
          text: TextSpan(
            text: 'Scan / Import to connect',
            style: GoogleFonts.poppins(
              fontSize: 38,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        instructionPainter.layout();
        instructionPainter.paint(
          canvas,
          Offset((imageSize - instructionPainter.width) / 2, 1320),
        );

        // Convert to image
        final picture = pictureRecorder.endRecording();
        final img =
            await picture.toImage(imageSize.toInt(), imageHeight.toInt());
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/cardflow_qr_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);

        debugPrint('✅ QR image saved: ${file.path}');

        // Share the file
        final result = await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Scan this QR code to get my business card!',
        );

        debugPrint('✅ QR code shared successfully: ${result.status}');
      }
    } catch (e) {
      debugPrint('❌ Error sharing QR code: $e');
      _showErrorSnackbar('Failed to share QR code: $e');
    }
  }

  // ============================================
  // NEARBY SHARE METHODS (Premium Feature)
  // ============================================

  /// Share card via Nearby Share (sender)
  Future<void> _shareViaNearby() async {
    if (_selectedCardId.isEmpty) {
      _showErrorSnackbar('Please select a card first');
      return;
    }

    try {
      // Request permissions
      bool hasPermissions = await _nearbyShare.requestPermissions();
      if (!hasPermissions) {
        _showErrorSnackbar('Required permissions not granted');
        return;
      }

      final selectedCard = _myCards.firstWhere(
        (card) => card['id'] == _selectedCardId,
      );
      final cardDataString = _encodeCardData(selectedCard);
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? user?.email ?? 'CardFlow User';

      // Get local image path if exists
      String? imagePath;
      try {
        imagePath = await LocalImageService().getCardImagePath(_selectedCardId);
        if (imagePath != null) {
          debugPrint('📸 Found local image to share: $imagePath');
        } else {
          debugPrint('⚠️ No local image found for card');
        }
      } catch (e) {
        debugPrint('⚠️ Error getting image path: $e');
      }

      // Show sharing dialog with premium animation
      _showNearbySharingDialog();

      // Start advertising
      bool success = await _nearbyShare.startSharing(
        cardData: cardDataString,
        userName: userName,
        imagePath: imagePath,
      );

      if (!success) {
        Navigator.pop(context);
        _showErrorSnackbar('Failed to start sharing');
        return;
      }

      // Track analytics
      AnalyticsService.trackCardShare(cardId: _selectedCardId);

      // Success will be handled by callbacks
    } catch (e) {
      debugPrint('❌ Error in _shareViaNearby: $e');
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackbar('Error sharing card: $e');
    }
  }

  /// Receive card via Nearby Share (receiver)
  Future<void> _receiveViaNearby() async {
    try {
      // Request permissions
      bool hasPermissions = await _nearbyShare.requestPermissions();
      if (!hasPermissions) {
        _showErrorSnackbar('Required permissions not granted');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? user?.email ?? 'CardFlow User';

      // Show receiving dialog with premium animation
      _showNearbyReceivingDialog();

      // Start discovering
      bool success = await _nearbyShare.startReceiving(
        userName: userName,
      );

      if (!success) {
        Navigator.pop(context);
        _showErrorSnackbar('Failed to start receiving');
        return;
      }

      // Data reception will be handled by callbacks
    } catch (e) {
      debugPrint('❌ Error in _receiveViaNearby: $e');
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackbar('Error receiving card: $e');
    }
  }

  void _shareViaNfc() async {
    if (_selectedCardId.isEmpty) {
      _showErrorSnackbar('Please select a card first');
      return;
    }

    final selectedCard =
        _myCards.firstWhere((card) => card['id'] == _selectedCardId);
    final cardDataString = _encodeCardData(selectedCard);

    _showNfcSharingDialog();

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            var ndef = Ndef.from(tag);
            if (ndef != null && ndef.isWritable) {
              NdefMessage message = NdefMessage([
                NdefRecord.createText(cardDataString),
              ]);

              await ndef.write(message);

              // Track NFC share analytics
              AnalyticsService.trackCardShare(cardId: _selectedCardId);

              Navigator.pop(context); // Close dialog
              _showSuccessSnackbar('Card shared via NFC successfully!');
            } else {
              Navigator.pop(context);
              _showErrorSnackbar('Tag is not writable');
            }
          } catch (e) {
            Navigator.pop(context);
            _showErrorSnackbar('Error writing to NFC: $e');
          } finally {
            NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackbar('NFC Error: $e');
    }
  }

  void _receiveViaNfc() {
    _showNfcReceivingDialog();

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            var ndef = Ndef.from(tag);
            if (ndef != null) {
              NdefMessage? message = await ndef.read();
              if (message.records.isNotEmpty) {
                String payload = String.fromCharCodes(
                  message.records.first.payload.skip(3),
                );
                Navigator.pop(context); // Close dialog
                Map<String, dynamic> cardData = _decodeCardData(payload);
                _showReceivedCardDialog(cardData);
              }
            } else {
              Navigator.pop(context);
              _showErrorSnackbar('No data found on tag');
            }
          } catch (e) {
            Navigator.pop(context);
            _showErrorSnackbar('Error reading NFC: $e');
          } finally {
            NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackbar('NFC Error: $e');
    }
  }

  void _copyShareLink() {
    if (_selectedCardId.isEmpty) {
      _showErrorSnackbar('Please select a card first');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? user?.email ?? user?.uid ?? 'user';
    final shareLink = 'cardflow://share?user=$username&cardId=$_selectedCardId';

    Clipboard.setData(ClipboardData(text: shareLink));
    _showSuccessSnackbar('Share link copied to clipboard!');
  }

  void _showNfcSharingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassmorphicContainer(
          width: 300,
          height: 350,
          borderRadius: 25,
          blur: 20,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.8),
            ],
          ),
          borderGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.5),
              Colors.white.withOpacity(0.2),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.nfc,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Hold Near Device',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap your phone to another NFC-enabled device to share your card',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () {
                    NfcManager.instance.stopSession();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF667eea),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNfcReceivingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassmorphicContainer(
          width: 300,
          height: 350,
          borderRadius: 25,
          blur: 20,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.8),
            ],
          ),
          borderGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.5),
              Colors.white.withOpacity(0.2),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contactless,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Ready to Receive',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hold your phone near an NFC tag or device to receive a card',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () {
                    NfcManager.instance.stopSession();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF667eea),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // NEARBY SHARE PREMIUM DIALOGS
  // ============================================

  /// Show premium sharing dialog with ripple animation
  void _showNearbySharingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 320,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: GlassmorphicContainer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 30,
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
              ),
              borderGradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.5),
                  const Color(0xFF764ba2).withOpacity(0.3),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premium animated icon with ripple effect (smaller size)
                      SizedBox(
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ripple effects (reduced size)
                            ...List.generate(3, (index) {
                              return AnimatedBuilder(
                                animation: _rippleController,
                                builder: (context, child) {
                                  final delay = index * 0.33;
                                  final value = (_rippleAnimation.value - delay)
                                      .clamp(0.0, 1.0);
                                  return Container(
                                    width: 90 + (value * 40),
                                    height: 90 + (value * 40),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF667eea)
                                            .withOpacity(1 - value),
                                        width: 2,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                            // Main icon with pulse (reduced size)
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF667eea)
                                          .withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.wifi_tethering,
                                  color: Colors.white,
                                  size: 45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sharing Nearby',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedCardTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF667eea),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bring phones close together',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Receiver should tap "Receive Nearby"',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _nearbyShare.stopSharing();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show premium receiving dialog with scan animation
  void _showNearbyReceivingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 320,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: GlassmorphicContainer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 30,
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
              ),
              borderGradient: LinearGradient(
                colors: [
                  const Color(0xFF2ebf91).withOpacity(0.5),
                  const Color(0xFF8360c3).withOpacity(0.3),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premium animated icon with radar effect (smaller size)
                      SizedBox(
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Radar scanning effect (reduced size)
                            ...List.generate(3, (index) {
                              return AnimatedBuilder(
                                animation: _rippleController,
                                builder: (context, child) {
                                  final delay = index * 0.33;
                                  final value = (_rippleAnimation.value - delay)
                                      .clamp(0.0, 1.0);
                                  return Container(
                                    width: 90 + (value * 40),
                                    height: 90 + (value * 40),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF2ebf91)
                                            .withOpacity(1 - value),
                                        width: 2,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                            // Main icon with pulse (reduced size)
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2ebf91),
                                      Color(0xFF8360c3)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2ebf91)
                                          .withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.phonelink_ring,
                                  color: Colors.white,
                                  size: 45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Searching Nearby',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(3, (index) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration:
                                  Duration(milliseconds: 600 + (index * 200)),
                              builder: (context, value, child) {
                                return Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2ebf91)
                                        .withOpacity(value),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Waiting for nearby cards',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sender should tap "Share Nearby"',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _nearbyShare.stopReceiving();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ebf91),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveReceivedCard(Map<String, dynamic> cardData) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user is trying to scan their own card
      final currentUsername = user.displayName ?? user.email ?? user.uid;
      final sharedBy = cardData['sharedBy'];

      if (sharedBy != null && sharedBy == currentUsername) {
        print('⚠️ Cannot receive your own card!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot save your own card! This is already in "My Cards"',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Add timestamp when received
      cardData['receivedAt'] = DateTime.now().millisecondsSinceEpoch;

      // Extract original card ID for preventing duplicates
      String? originalCardId = cardData['originalCardId'];

      // Backward compatibility: If old QR code without cardId, generate one
      if (originalCardId == null || originalCardId.isEmpty) {
        print('⚠️ Old QR code format detected (missing cardId)');
        print(
            '⚠️ Using push() for backward compatibility - duplicates possible');
        originalCardId = FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.displayName ?? user.uid)
            .child('receivedCards')
            .push()
            .key!;
        cardData['originalCardId'] = originalCardId;
        print('📊 Generated new ID: $originalCardId');
      }

      // Check if this card already exists in user's own cards (prevent scanning own old QR)
      final ownCardRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUsername)
          .child(originalCardId);

      final ownCardSnapshot = await ownCardRef.get();
      if (ownCardSnapshot.exists) {
        print('⚠️ This card already exists in your My Cards!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This card is already in "My Cards"! Cannot add to received cards.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      print(
          '📊 Saving card from: ${cardData['sharedBy'] ?? "unknown"} with ID: $originalCardId');
      print('📊 Card has themeData: ${cardData['themeData'] != null}');
      if (cardData['themeData'] != null) {
        print('📊 ThemeData: ${cardData['themeData']}');
      }

      // Save to Firebase using displayName/username structure with receivedCards folder
      await FirebaseDatabase.instance
          .ref('users')
          .child(user.displayName ?? user.uid)
          .child('receivedCards')
          .child(originalCardId)
          .set({
        ...cardData,
        'receivedAt': ServerValue.timestamp,
      });

      print('✅ Card saved/updated in receivedCards with ID: $originalCardId');

      // Copy received image to local storage if available
      if (_receivedImagePath != null) {
        try {
          debugPrint('📸 Copying received image to local storage...');
          debugPrint('📸 Image URI: $_receivedImagePath');

          // Read bytes from the content URI
          final file = File(_receivedImagePath!);
          final imageBytes = await file.readAsBytes();
          debugPrint('📸 Read ${imageBytes.length} bytes from image');

          // Save using bytes method
          await LocalImageService().saveCardImageFromBytes(
            originalCardId,
            imageBytes,
          );
          debugPrint('✅ Image saved locally for card: $originalCardId');
          _receivedImagePath = null; // Clear temporary storage
        } catch (e) {
          debugPrint('❌ Error saving received image: $e');
        }
      }

      // Show success message (with warning for old QR codes)
      if (mounted) {
        final isOldQR = cardData['sharedBy'] == null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOldQR
                      ? '⚠️ Card saved with old QR format'
                      : '✅ Card saved to My Network!',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (isOldQR)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Ask card owner to regenerate QR code in Card Sharing Hub → My Cards → Generate QR for better tracking & duplicate prevention',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            backgroundColor: isOldQR ? Colors.orange : Colors.green,
            duration: Duration(seconds: isOldQR ? 5 : 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving received card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save card',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReceivedCardDialog(Map<String, dynamic> cardData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive sizing
            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;

            final dialogWidth = (screenWidth * 0.88).clamp(300.0, 380.0);
            final dialogPadding = (screenWidth * 0.05).clamp(16.0, 25.0);
            final iconSize = (screenWidth * 0.12).clamp(50.0, 60.0);
            final titleSize = (screenWidth * 0.055).clamp(20.0, 24.0);
            final infoPadding = (screenWidth * 0.035).clamp(12.0, 15.0);
            final buttonPadding = (screenHeight * 0.018).clamp(12.0, 15.0);
            final spacing1 = (screenHeight * 0.018).clamp(12.0, 20.0);
            final spacing2 = (screenHeight * 0.022).clamp(15.0, 25.0);

            return GlassmorphicContainer(
              width: dialogWidth,
              height: (screenHeight * 0.7).clamp(450.0, 580.0),
              borderRadius: 25,
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.8),
                ],
              ),
              borderGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.2),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(dialogPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2ebf91), Color(0xFF8360c3)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: iconSize * 0.58,
                      ),
                    ),
                    SizedBox(height: spacing1),
                    Text(
                      'Card Received!',
                      style: GoogleFonts.poppins(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: spacing1),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: EdgeInsets.all(infoPadding),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildInfoRow(Icons.business, 'Business',
                                  cardData['businessName']),
                              _buildInfoRow(
                                  Icons.person, 'Name', cardData['personName']),
                              _buildInfoRow(
                                  Icons.email, 'Email', cardData['email']),
                              _buildInfoRow(Icons.phone, 'Phone',
                                  cardData['contactNumber']),
                              _buildInfoRow(
                                  Icons.web, 'Website', cardData['website']),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing2),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.grey.shade800,
                              padding:
                                  EdgeInsets.symmetric(vertical: buttonPadding),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: (titleSize * 0.58).clamp(12.0, 14.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Save the card first
                              await _saveReceivedCard(cardData);

                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BusinessCardScreen(
                                    businessName:
                                        cardData['businessName'] ?? '',
                                    personName: cardData['personName'] ?? '',
                                    website: cardData['website'] ?? '',
                                    email: cardData['email'] ?? '',
                                    contactNumber:
                                        cardData['contactNumber'] ?? '',
                                    image: cardData['imageUrl'] ?? '',
                                    themeId: cardData['themeId'],
                                    themeData: cardData['themeData'],
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              padding:
                                  EdgeInsets.symmetric(vertical: buttonPadding),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Save & View',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: (titleSize * 0.58).clamp(12.0, 14.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  value ?? 'N/A',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNfcNotAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'NFC is not available on this device',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _encodeCardData(Map<String, dynamic> card) {
    debugPrint('🔍 Encoding card data...');
    debugPrint('Card has themeData: ${card['themeData'] != null}');
    if (card['themeData'] != null) {
      debugPrint('ThemeData type: ${card['themeData'].runtimeType}');
      debugPrint('ThemeData contents: ${card['themeData']}');
    }
    debugPrint('Card has themeId: ${card['themeId']}');

    // Get owner userId, username, and photo for connections and analytics
    final user = FirebaseAuth.instance.currentUser;
    final ownerId = user?.uid ?? ''; // ACTUAL userId for connections!
    final ownerUsername =
        user?.displayName ?? user?.email ?? user?.uid ?? 'unknown';
    final ownerPhoto = user?.photoURL ?? ''; // Get sender's photo URL
    debugPrint('Owner ID: $ownerId');
    debugPrint('Owner username: $ownerUsername');
    debugPrint('Owner photo: $ownerPhoto');
    debugPrint('Card ID: ${card['id']}');

    // Include theme data in the QR code with explicit type conversion
    String themeData = '';
    if (card['themeData'] != null && card['themeData'] is Map) {
      final theme = card['themeData'] as Map<String, dynamic>;
      themeData =
          '${theme['themeId'] ?? ''}~${theme['gradientColor1'] ?? ''}~${theme['gradientColor2'] ?? ''}~${theme['textColor'] ?? ''}~${theme['accentColor'] ?? ''}~${theme['fontFamily'] ?? ''}~${theme['borderRadius'] ?? ''}~${theme['hasGlassEffect'] ?? ''}';
      debugPrint('✅ Encoded theme data: $themeData');
    } else {
      debugPrint('❌ No valid themeData to encode');
    }

    // Add cardId (parts[8]), ownerUsername (parts[9]), ownerPhoto (parts[10]), and ownerId (parts[11])
    final encoded =
        '${card['businessName']}|${card['personName']}|${card['email']}|${card['contactNumber']}|${card['website']}|${card['imageUrl'] ?? ''}|${card['themeId'] ?? ''}|$themeData|${card['id'] ?? ''}|$ownerUsername|$ownerPhoto|$ownerId';
    debugPrint('Full encoded string length: ${encoded.length}');
    debugPrint('Full encoded string: $encoded');

    return encoded;
  }

  Map<String, dynamic> _decodeCardData(String data) {
    debugPrint('🔍 Decoding QR data...');
    debugPrint('Raw QR data length: ${data.length}');

    List<String> parts = data.split('|');
    debugPrint('Split into ${parts.length} parts');

    Map<String, dynamic> cardData = {
      'businessName': parts.length > 0 ? parts[0] : '',
      'personName': parts.length > 1 ? parts[1] : '',
      'email': parts.length > 2 ? parts[2] : '',
      'contactNumber': parts.length > 3 ? parts[3] : '',
      'website': parts.length > 4 ? parts[4] : '',
      'imageUrl': parts.length > 5 ? parts[5] : '',
      'themeId': parts.length > 6 ? parts[6] : '',
    };

    // Decode theme data if present
    if (parts.length > 7 && parts[7].isNotEmpty) {
      debugPrint('Found theme data in QR: ${parts[7]}');
      List<String> themeParts = parts[7].split('~');
      debugPrint('Theme parts count: ${themeParts.length}');

      if (themeParts.length >= 8) {
        cardData['themeData'] = {
          'themeId': themeParts[0],
          'gradientColor1': themeParts[1],
          'gradientColor2': themeParts[2],
          'textColor': themeParts[3],
          'accentColor': themeParts[4],
          'fontFamily': themeParts[5],
          'borderRadius': themeParts[6].isNotEmpty
              ? double.tryParse(themeParts[6]) ?? 20.0
              : 20.0,
          'hasGlassEffect': themeParts[7] == 'true',
        };
        debugPrint('✅ Theme data decoded successfully');
      } else {
        debugPrint('❌ Theme parts insufficient: ${themeParts.length}');
      }
    } else {
      debugPrint('❌ No theme data found in QR (parts: ${parts.length})');
    }

    // Extract analytics tracking metadata (parts[8], parts[9], parts[10], and parts[11])
    if (parts.length > 8) {
      cardData['originalCardId'] = parts[8];
      debugPrint('📊 Original card ID: ${parts[8]}');
    }
    if (parts.length > 9) {
      cardData['sharedByUsername'] = parts[9]; // Username for display
      debugPrint('📊 Shared by username: ${parts[9]}');
    }
    if (parts.length > 10 && parts[10].isNotEmpty) {
      cardData['sharedByPhoto'] = parts[10];
      debugPrint('📊 Shared by photo: ${parts[10]}');
    }
    if (parts.length > 11 && parts[11].isNotEmpty) {
      cardData['sharedBy'] = parts[11]; // Actual userId for connections!
      debugPrint('📊 Shared by userId: ${parts[11]}');
    } else if (parts.length > 9) {
      // Backward compatibility: if no userId (parts[11]), use username as fallback
      cardData['sharedBy'] = parts[9];
      debugPrint('⚠️ Using username as userId (old QR format)');
    }

    return cardData;
  }
}

// QR Scanner Screen
class QrScannerScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onCardReceived;

  const QrScannerScreen({Key? key, required this.onCardReceived})
      : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Scan QR Code',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                return const Icon(Icons.cameraswitch);
              },
            ),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (!_hasScanned) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _hasScanned = true;
                    final cardData = _decodeCardData(barcode.rawValue!);
                    Navigator.pop(context);
                    widget.onCardReceived(cardData);
                    break;
                  }
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Align QR code within frame',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _decodeCardData(String data) {
    debugPrint('🔍 [QrScanner] Decoding QR data...');
    debugPrint('Raw QR data length: ${data.length}');

    List<String> parts = data.split('|');
    debugPrint('Split into ${parts.length} parts');

    Map<String, dynamic> cardData = {
      'businessName': parts.length > 0 ? parts[0] : '',
      'personName': parts.length > 1 ? parts[1] : '',
      'email': parts.length > 2 ? parts[2] : '',
      'contactNumber': parts.length > 3 ? parts[3] : '',
      'website': parts.length > 4 ? parts[4] : '',
      'imageUrl': parts.length > 5 ? parts[5] : '',
      'themeId': parts.length > 6 ? parts[6] : '',
    };

    // Decode theme data if present
    if (parts.length > 7 && parts[7].isNotEmpty) {
      debugPrint('Found theme data in QR: ${parts[7]}');
      List<String> themeParts = parts[7].split('~');
      debugPrint('Theme parts count: ${themeParts.length}');

      if (themeParts.length >= 8) {
        cardData['themeData'] = {
          'themeId': themeParts[0],
          'gradientColor1': themeParts[1],
          'gradientColor2': themeParts[2],
          'textColor': themeParts[3],
          'accentColor': themeParts[4],
          'fontFamily': themeParts[5],
          'borderRadius': themeParts[6].isNotEmpty
              ? double.tryParse(themeParts[6]) ?? 20.0
              : 20.0,
          'hasGlassEffect': themeParts[7] == 'true',
        };
        debugPrint('✅ Theme data decoded successfully');
        debugPrint('ThemeData: ${cardData['themeData']}');
      } else {
        debugPrint('❌ Theme parts insufficient: ${themeParts.length}');
      }
    } else {
      debugPrint('❌ No theme data found in QR (parts: ${parts.length})');
    }

    // Extract analytics tracking metadata (parts[8] and parts[9])
    if (parts.length > 8) {
      cardData['originalCardId'] = parts[8];
      debugPrint('📊 Original card ID: ${parts[8]}');
    }
    if (parts.length > 9) {
      cardData['sharedBy'] = parts[9];
      debugPrint('📊 Shared by: ${parts[9]}');
    }

    return cardData;
  }
}
