import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cardflow/widgets/animated_gradient_container.dart';
import 'package:cardflow/services/card_customization_service.dart'
    as customization;
import 'package:cardflow/screens/submission_screen.dart';
import 'package:cardflow/screens/card_sharing_hub.dart';
import 'package:cardflow/screens/card_creation_wizard.dart';
import 'package:cardflow/screens/analytics_screen.dart';
import 'package:cardflow/screens/received_cards_screen.dart';
import 'package:cardflow/screens/my_connections_screen.dart';
import 'package:cardflow/services/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  _ModernHomeScreenState createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _personNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  bool _isLoading = false;
  String? _selectedImagePath;
  customization.CardTheme? _selectedTheme;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSelectedTheme();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  Future<void> _loadSelectedTheme() async {
    final theme =
        await customization.CardCustomizationService.getSelectedTheme();
    setState(() {
      _selectedTheme = theme;
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _personNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully logged out'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error logging out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImagePath = pickedFile.path;
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user =
            Provider.of<AuthService>(context, listen: false).currentUser;
        final userId = user?.uid ?? '';

        if (userId.isEmpty) {
          throw Exception('User not authenticated');
        }

        final userData = {
          'businessName': _businessNameController.text,
          'personName': _personNameController.text,
          'contactNumber': _contactNumberController.text,
          'email': _emailController.text,
          'website': _websiteController.text,
          'themeId': _selectedTheme?.id ?? 'professional_blue',
        };

        await FirestoreService().submitUserData(
          userId: userId,
          userData: userData,
          imagePath: _selectedImagePath,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Business card created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          _selectedImagePath = null;
          _businessNameController.clear();
          _personNameController.clear();
          _contactNumberController.clear();
          _emailController.clear();
          _websiteController.clear();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.grey.shade100.withOpacity(0.7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> gradientColors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive height based on screen width
          final double cardHeight = constraints.maxWidth * 0.85;
          final double clampedHeight = cardHeight.clamp(120.0, 160.0);

          return GlassmorphicContainer(
            width: double.infinity,
            height: clampedHeight,
            borderRadius: 20,
            blur: 30,
            alignment: Alignment.bottomCenter,
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
            child: Padding(
              padding: EdgeInsets.all(
                  clampedHeight * 0.12), // Reduced from 0.14 to 0.12
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize:
                    MainAxisSize.max, // Ensure column fills available space
                children: [
                  Container(
                    width: clampedHeight * 0.37,
                    height: clampedHeight * 0.37,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gradientColors.first.withOpacity(0.75),
                          gradientColors.last.withOpacity(0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors.first.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(icon,
                          color: Colors.white, size: clampedHeight * 0.185),
                    ),
                  ),
                  Flexible(
                    // Wrap text column in Flexible
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade800,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(
                            height: clampedHeight *
                                0.02), // Slightly reduced spacing
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return Scaffold(
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Header
                      AnimationConfiguration.staggeredList(
                        position: 0,
                        duration: const Duration(milliseconds: 800),
                        child: SlideAnimation(
                          verticalOffset: -50.0,
                          child: FadeInAnimation(
                            child: _buildModernHeader(user),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Quick Actions Grid
                      AnimationConfiguration.staggeredList(
                        position: 1,
                        duration: const Duration(milliseconds: 800),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildQuickActionsGrid(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Create New Card Section
                      AnimationConfiguration.staggeredList(
                        position: 2,
                        duration: const Duration(milliseconds: 800),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildCreateCardSection(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
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

  Widget _buildModernHeader(user) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 90,
      borderRadius: 22,
      blur: 30,
      alignment: Alignment.bottomCenter,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            if (user?.photoURL != null)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea).withOpacity(0.3),
                      const Color(0xFF764ba2).withOpacity(0.3),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(user!.photoURL!),
                  radius: 24,
                  backgroundColor: Colors.transparent,
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4a5cc5).withOpacity(0.2),
                      const Color(0xFF5d3a85).withOpacity(0.2),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4a5cc5).withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    Icon(Icons.person, color: Colors.grey.shade700, size: 24),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.displayName ?? 'User',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.logout, color: Colors.grey.shade700, size: 20),
                onPressed: _isLoading ? null : _logout,
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            color: Colors.grey.shade800,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        // Row 1: My Cards and Share & Receive
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'My Cards',
                subtitle: 'View & manage',
                icon: Icons.credit_card,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MySubmissionsScreen()),
                ),
                gradientColors: [
                  const Color(0xFF4a5cc5).withOpacity(0.75), // Dimmed purple
                  const Color(0xFF5d3a85).withOpacity(0.75)
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Send Receive',
                subtitle: 'Exchange cards',
                icon: Icons.swap_horiz,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CardSharingHub()),
                ),
                gradientColors: [
                  const Color(0xFF248c6f).withOpacity(0.75), // Dimmed teal
                  const Color(0xFF6b4c9d).withOpacity(0.75)
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 2: My Network and Analytics
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'My Network',
                subtitle: 'Received cards',
                icon: Icons.people_alt_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReceivedCardsScreen()),
                ),
                gradientColors: [
                  const Color(0xFFe67e22).withOpacity(0.75), // Orange
                  const Color(0xFFe74c3c).withOpacity(0.75) // Red-orange
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Analytics',
                subtitle: 'Track engagement',
                icon: Icons.analytics,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen()),
                ),
                gradientColors: [
                  const Color(0xFF3a8cfe).withOpacity(0.75), // Blue
                  const Color(0xFF00c2fe).withOpacity(0.75) // Light blue
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 3: My Connections (half width to match other cards)
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'My Connections',
                subtitle: 'Chat & connect',
                icon: Icons.connect_without_contact,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyConnectionsScreen()),
                ),
                gradientColors: [
                  const Color(0xFF667eea).withOpacity(0.75), // Purple
                  const Color(0xFF764ba2).withOpacity(0.75) // Deep purple
                ],
              ),
            ),
            const SizedBox(width: 15),
            // Empty space to match 2-column layout
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildCreateCardSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make height responsive but with reasonable limits
        final double sectionHeight = MediaQuery.of(context).size.height * 0.22;
        final double clampedHeight = sectionHeight.clamp(180.0, 220.0);

        return GlassmorphicContainer(
          width: double.infinity,
          height: clampedHeight,
          borderRadius: 25,
          blur: 30,
          alignment: Alignment.bottomCenter,
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
          child: Padding(
            padding: EdgeInsets.all(clampedHeight * 0.12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4a5cc5)
                                .withOpacity(0.75), // Dimmed colors
                            const Color(0xFF5d3a85).withOpacity(0.75)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4a5cc5).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_card,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Create Your Card',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade800,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Design and customize',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CardCreationWizard(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4a5cc5), // Dimmed color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF4a5cc5).withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_card, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Create Card',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
