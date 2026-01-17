import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/card_customization_service.dart' as customization;
import '../widgets/animated_gradient_container.dart';
import 'submission_screen.dart';

class CardCreationWizard extends StatefulWidget {
  const CardCreationWizard({Key? key}) : super(key: key);

  @override
  State<CardCreationWizard> createState() => _CardCreationWizardState();
}

class _CardCreationWizardState extends State<CardCreationWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Theme selection
  customization.CardTheme? _selectedTheme;
  bool _isCustomTheme = false;

  // Custom theme colors
  Color _customGradient1 = const Color(0xFF667eea);
  Color _customGradient2 = const Color(0xFF764ba2);
  Color _customTextColor = Colors.white;

  // Form data
  String? _selectedImagePath;
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _personNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _businessNameController.dispose();
    _personNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Calculate total number of pages based on custom theme selection
    // Without custom theme: 8 pages (0-7): Theme, Picture, Business, Name, Contact, Email, Website, Preview
    // With custom theme: 9 pages (0-8): Theme, CustomBuilder, Picture, Business, Name, Contact, Email, Website, Preview
    final lastPageIndex = _isCustomTheme ? 8 : 7;

    debugPrint(
        '📄 _nextPage called. Current page: $_currentPage, Last page index: $lastPageIndex');

    if (_currentPage < lastPageIndex) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage++;
        debugPrint('📄 Moved to page: $_currentPage');
      });
    } else {
      debugPrint('⚠️ Already at last page');
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  void _selectTheme(customization.CardTheme theme) {
    setState(() {
      _selectedTheme = theme;
      _isCustomTheme = false;
    });
    _nextPage();
  }

  void _selectCustomTheme() {
    setState(() {
      _isCustomTheme = true;
    });
    _nextPage();
  }

  void _confirmCustomTheme() {
    setState(() {
      _selectedTheme = customization.CardTheme(
        id: 'custom',
        name: 'Custom Theme',
        gradientColors: [_customGradient1, _customGradient2],
        textColor: _customTextColor,
        accentColor: _customGradient1,
        fontFamily: 'Poppins',
        cardRadius: 20.0,
        hasGlassEffect: true,
      );
    });
    _nextPage();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _submitCard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final userId = user?.uid ?? '';

      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final userData = {
        'businessName': _businessNameController.text,
        'personName': _personNameController.text,
        'contactNumber': _contactController.text,
        'email': _emailController.text,
        'website': _websiteController.text,
        'themeData': {
          'themeId': _selectedTheme?.id ?? 'professional_blue',
          'gradientColor1':
              _selectedTheme?.gradientColors[0].value.toRadixString(16) ??
                  'FF667eea',
          'gradientColor2':
              _selectedTheme?.gradientColors[1].value.toRadixString(16) ??
                  'FF764ba2',
          'textColor':
              _selectedTheme?.textColor.value.toRadixString(16) ?? 'FFFFFFFF',
          'accentColor':
              _selectedTheme?.accentColor.value.toRadixString(16) ?? 'FF667eea',
          'fontFamily': _selectedTheme?.fontFamily ?? 'Poppins',
          'borderRadius': _selectedTheme?.cardRadius ?? 20.0,
          'hasGlassEffect': _selectedTheme?.hasGlassEffect ?? true,
        },
      };

      await FirestoreService().submitUserData(
        userId: userId,
        userData: userData,
        imagePath: _selectedImagePath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Business card created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MySubmissionsScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          child: Column(
            children: [
              // App Bar with back button and title - Always visible
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 20),
                        onPressed: _currentPage > 0
                            ? _previousPage
                            : () => Navigator.pop(context),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentPage == 0
                                ? 'Create Your Card'
                                : _getStepTitle(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.4),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          if (_currentPage > 0) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _currentPage / 7,
                                backgroundColor: Colors.white.withOpacity(0.25),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildThemeSelectionPage(),
                    if (_isCustomTheme) _buildCustomThemeBuilderPage(),
                    _buildFormPage(
                      title: 'Profile Picture',
                      subtitle: 'Add your photo (optional)',
                      child: _buildImagePicker(),
                      isOptional: true,
                    ),
                    _buildFormPage(
                      title: 'Business Name',
                      subtitle: 'Enter your company or business name',
                      child: _buildTextField(
                        controller: _businessNameController,
                        hint: 'e.g., Tech Solutions Inc.',
                        icon: Icons.business,
                      ),
                    ),
                    _buildFormPage(
                      title: 'Your Name',
                      subtitle: 'Enter your full name',
                      child: _buildTextField(
                        controller: _personNameController,
                        hint: 'e.g., John Doe',
                        icon: Icons.person,
                      ),
                    ),
                    _buildFormPage(
                      title: 'Contact Number',
                      subtitle: 'Enter your phone number (optional)',
                      isOptional: true,
                      child: _buildTextField(
                        controller: _contactController,
                        hint: 'e.g., 1234567890',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                      ),
                    ),
                    _buildFormPage(
                      title: 'Email Address',
                      subtitle: 'Enter your email (optional)',
                      isOptional: true,
                      child: _buildTextField(
                        controller: _emailController,
                        hint: 'e.g., john@example.com',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    _buildFormPage(
                      title: 'Website',
                      subtitle: 'Enter your website URL (optional)',
                      child: _buildTextField(
                        controller: _websiteController,
                        hint: 'e.g., https://example.com',
                        icon: Icons.language,
                        keyboardType: TextInputType.url,
                      ),
                      isOptional: true,
                    ),
                    _buildFinalPreviewPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentPage) {
      case 0:
        return 'Choose Theme';
      case 1:
        return _isCustomTheme ? 'Customize Theme' : 'Step 1 of 6';
      case 2:
        return 'Step ${_isCustomTheme ? 1 : 1} of 6';
      case 3:
        return 'Step ${_isCustomTheme ? 2 : 2} of 6';
      case 4:
        return 'Step ${_isCustomTheme ? 3 : 3} of 6';
      case 5:
        return 'Step ${_isCustomTheme ? 4 : 4} of 6';
      case 6:
        return 'Step ${_isCustomTheme ? 5 : 5} of 6';
      case 7:
        return 'Step ${_isCustomTheme ? 6 : 6} of 6';
      default:
        return 'Final Review';
    }
  }

  // Theme Selection Page
  Widget _buildThemeSelectionPage() {
    final themes = customization.CardCustomizationService.getDefaultThemes();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.35),
                  Colors.white.withOpacity(0.20),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(-8, -8),
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.4),
                              Colors.white.withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Your Card Design',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.6),
                                    offset: const Offset(0, 3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select a pre-designed theme or create your own',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.1),
                                    offset: const Offset(0, 2),
                                    blurRadius: 6,
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
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: themes.length + 1,
            itemBuilder: (context, index) {
              if (index == themes.length) {
                return _buildCustomThemeCard();
              }
              return _buildThemeCard(themes[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(customization.CardTheme theme) {
    return GestureDetector(
      onTap: () => _selectTheme(theme),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.gradientColors[0].withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.credit_card,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      theme.name,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: theme.gradientColors[0],
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
      ),
    );
  }

  Widget _buildCustomThemeCard() {
    return GestureDetector(
      onTap: _selectCustomTheme,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF6B6B),
              Color(0xFFFFD93D),
              Color(0xFF6BCF7F),
              Color(0xFF4D96FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF4D96FF).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Multiple sparkle indicators
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFFF8C00),
                  size: 10,
                ),
              ),
            ),
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  color: Color(0xFFFFD93D),
                  size: 8,
                ),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.palette,
                      color: Color(0xFFFF6B6B),
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.brush,
                                color: Color(0xFFFF6B6B), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              'Create Your Own',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF6B6B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD93D), Color(0xFFFF8C00)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '✨ Custom Theme',
                            style: GoogleFonts.poppins(
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
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
    );
  }

  // Custom Theme Builder Page
  Widget _buildCustomThemeBuilderPage() {
    return Column(
      children: [
        // Live Preview Card - Top Section
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              // Preview Card
              Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_customGradient1, _customGradient2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _customGradient1.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sample Company',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _customTextColor,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'John Doe',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _customTextColor.withOpacity(0.95),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Your Custom Theme',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _customTextColor.withOpacity(0.9),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Color Picker Section - Bottom White Area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.90),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 25,
                  offset: const Offset(0, -8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize Colors',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2937),
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pick your favorite colors to create a unique theme',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Color Pickers
                  _buildColorPickerButton(
                    'Gradient Color 1',
                    _customGradient1,
                    (color) => setState(() => _customGradient1 = color),
                  ),
                  const SizedBox(height: 14),
                  _buildColorPickerButton(
                    'Gradient Color 2',
                    _customGradient2,
                    (color) => setState(() => _customGradient2 = color),
                  ),
                  const SizedBox(height: 14),
                  _buildColorPickerButton(
                    'Text Color',
                    _customTextColor,
                    (color) => setState(() => _customTextColor = color),
                  ),

                  const SizedBox(height: 32),

                  // Done Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667eea).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _confirmCustomTheme,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Done - Use This Theme',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPickerButton(
      String label, Color currentColor, Function(Color) onColorChanged) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: currentColor,
                onColorChanged: onColorChanged,
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: currentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit,
                color: Color(0xFF667eea),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Form Page with Card Preview
  Widget _buildFormPage({
    required String title,
    required String subtitle,
    required Widget child,
    bool isOptional = false,
  }) {
    return Column(
      children: [
        // Card Preview - Compact Size
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          constraints: const BoxConstraints(
            maxHeight: 140,
          ),
          child: _buildLiveCardPreview(),
        ),

        // Form Field - Takes remaining space
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.90),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 25,
                  offset: const Offset(0, -8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2937),
                      letterSpacing: -0.8,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  child,
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (isOptional)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _nextPage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              side: const BorderSide(
                                color: Color(0xFF667eea),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF667eea),
                              ),
                            ),
                          ),
                        ),
                      if (isOptional) const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (_validateCurrentField(title)) {
                                _nextPage();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Next',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _validateCurrentField(String title) {
    debugPrint('🔍 Validating field: $title');
    switch (title) {
      case 'Business Name':
        if (_businessNameController.text.trim().isEmpty) {
          _showError('Please enter a business name');
          return false;
        }
        break;
      case 'Your Name':
        if (_personNameController.text.trim().isEmpty) {
          _showError('Please enter your name');
          return false;
        }
        break;
      case 'Contact Number':
        // Only validate if contact number is not empty
        if (_contactController.text.trim().isNotEmpty) {
          debugPrint('📞 Contact value: "${_contactController.text}"');
          if (_contactController.text.length != 10) {
            _showError('Please enter a valid 10-digit phone number');
            return false;
          }
        }
        break;
      case 'Email Address':
        // Only validate if email is not empty
        if (_emailController.text.trim().isNotEmpty) {
          debugPrint('📧 Email value: "${_emailController.text.trim()}"');
          final emailRegex =
              RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
          final isValid = emailRegex.hasMatch(_emailController.text.trim());
          debugPrint('📧 Email validation result: $isValid');
          if (!isValid) {
            _showError('Please enter a valid email address');
            return false;
          }
        } else {
          debugPrint('📧 Email is empty, skipping validation');
        }
        break;
    }
    debugPrint('✅ Validation passed for: $title');
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Live Card Preview
  Widget _buildLiveCardPreview() {
    if (_selectedTheme == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _selectedTheme!.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_selectedTheme!.cardRadius),
        boxShadow: [
          BoxShadow(
            color: _selectedTheme!.gradientColors[0].withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Left: Profile Picture
            _selectedImagePath != null
                ? Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: FileImage(File(_selectedImagePath!)),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _businessNameController.text.isNotEmpty
                            ? _businessNameController.text
                                .substring(
                                    0,
                                    _businessNameController.text.length > 1
                                        ? 2
                                        : 1)
                                .toUpperCase()
                            : 'PP',
                        style: GoogleFonts.poppins(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: _selectedTheme!.textColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

            const SizedBox(width: 14),

            // Right: Contact Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    _personNameController.text.isEmpty
                        ? 'John Doe'
                        : _personNameController.text,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _selectedTheme!.textColor,
                      letterSpacing: -0.3,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.25),
                          offset: const Offset(0, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  // Business Name
                  if (_businessNameController.text.isNotEmpty)
                    Text(
                      _businessNameController.text,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _selectedTheme!.textColor.withOpacity(0.85),
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 6),

                  // Contact Details
                  if (_contactController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2.5),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: _selectedTheme!.textColor.withOpacity(0.9),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _contactController.text,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: _selectedTheme!.textColor.withOpacity(0.9),
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.2),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_emailController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2.5),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_rounded,
                            size: 12,
                            color: _selectedTheme!.textColor.withOpacity(0.9),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _emailController.text,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color:
                                    _selectedTheme!.textColor.withOpacity(0.9),
                                letterSpacing: 0.1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_websiteController.text.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 12,
                          color: _selectedTheme!.textColor.withOpacity(0.9),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _websiteController.text,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: _selectedTheme!.textColor.withOpacity(0.9),
                              letterSpacing: 0.1,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.2),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
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
    );
  }

  // Image Picker Widget
  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            maxWidth: 400,
          ),
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 2,
              style: BorderStyle.solid,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _selectedImagePath == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 56,
                      color: const Color(0xFF667eea).withOpacity(0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to select image',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(_selectedImagePath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
        ),
      ),
    );
  }

  // Text Field Widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: const Color(0xFF2D3748),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 16,
            color: const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF667eea),
            size: 22,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: const Color(0xFFE5E7EB),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: const Color(0xFFE5E7EB),
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF667eea),
              width: 2.5,
            ),
          ),
          counterText: '',
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  // Final Preview Page
  Widget _buildFinalPreviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Header with better visibility
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                // Sparkle icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Card is Ready!',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                    letterSpacing: -0.8,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Review your professional business card below',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Premium Business Card Preview
          _buildPremiumCardPreview(),

          const SizedBox(height: 36),

          // Create Button
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Create Business Card',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Premium Business Card Preview for Final Page
  Widget _buildPremiumCardPreview() {
    if (_selectedTheme == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 200, // Fixed height to prevent overflow
      constraints: const BoxConstraints(
        maxWidth: 400,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: _selectedTheme!.gradientColors[0].withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _selectedTheme!.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              // Left: Profile Picture
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.7),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _selectedImagePath != null
                    ? CircleAvatar(
                        radius: 32,
                        backgroundImage: FileImage(File(_selectedImagePath!)),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _businessNameController.text.isNotEmpty
                                ? _businessNameController.text
                                    .substring(
                                        0,
                                        _businessNameController.text.length > 1
                                            ? 2
                                            : 1)
                                    .toUpperCase()
                                : 'PP',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.4),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(width: 14),

              // Right: All Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Person Name
                    Text(
                      _personNameController.text.isEmpty
                          ? 'John Doe'
                          : _personNameController.text,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 3),

                    // Business Name
                    if (_businessNameController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _businessNameController.text,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.95),
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
                                offset: const Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Contact Details - Compact
                    if (_contactController.text.isNotEmpty)
                      _buildContactRow(
                          Icons.phone_rounded, _contactController.text),

                    if (_emailController.text.isNotEmpty)
                      _buildContactRow(
                          Icons.email_rounded, _emailController.text),

                    if (_websiteController.text.isNotEmpty)
                      _buildContactRow(
                          Icons.language_rounded, _websiteController.text),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 11,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Old contact section removed - keeping for reference only
  void _oldContactSection() {
    // This method is just a placeholder for removed code
  }
}
