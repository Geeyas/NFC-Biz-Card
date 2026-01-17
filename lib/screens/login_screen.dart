import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/auth_service.dart';
import '../widgets/animated_gradient_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing
    final isSmallScreen = screenHeight < 650;
    final isTinyScreen = screenHeight < 550;
    final logoSize = isSmallScreen ? 80.0 : 100.0;
    final titleSize = isSmallScreen ? 22.0 : 26.0;
    final subtitleSize = isSmallScreen ? 13.0 : 15.0;

    return Scaffold(
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.08,
                      vertical: isSmallScreen ? 16 : 24,
                    ),
                    child: AnimationLimiter(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 600),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: [
                            // Top Spacer
                            SizedBox(height: isSmallScreen ? 10 : 20),

                            // Logo and Title
                            Column(
                              children: [
                                Container(
                                  width: logoSize,
                                  height: logoSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF667eea),
                                        const Color(0xFF764ba2),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF667eea)
                                            .withOpacity(0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.credit_card,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 16 : 24),
                                Text(
                                  'CardFlow',
                                  style: GoogleFonts.poppins(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade900,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 10),
                                Text(
                                  'Share your professional identity with style',
                                  style: GoogleFonts.poppins(
                                    fontSize: subtitleSize,
                                    color: Colors.grey.shade700,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),

                            SizedBox(height: isSmallScreen ? 30 : 50),

                            // Sign-in Card
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.25),
                                        Colors.white.withOpacity(0.15),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(23),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 20, sigmaY: 20),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isTinyScreen
                                              ? 16.0
                                              : (isSmallScreen ? 20.0 : 28.0),
                                          vertical: isTinyScreen
                                              ? 20.0
                                              : (isSmallScreen ? 24.0 : 32.0),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Welcome Back',
                                              style: GoogleFonts.poppins(
                                                fontSize: isTinyScreen
                                                    ? 18
                                                    : (isSmallScreen ? 20 : 24),
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade900,
                                              ),
                                            ),
                                            SizedBox(
                                                height: isTinyScreen
                                                    ? 4
                                                    : (isSmallScreen ? 6 : 10)),
                                            Text(
                                              'Continue with your Google account',
                                              style: GoogleFonts.poppins(
                                                fontSize: isTinyScreen
                                                    ? 11
                                                    : (isSmallScreen ? 12 : 14),
                                                color: Colors.grey.shade700,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(
                                                height: isTinyScreen
                                                    ? 16
                                                    : (isSmallScreen
                                                        ? 20
                                                        : 28)),

                                            // Google Sign-in Button
                                            SizedBox(
                                              width: double.infinity,
                                              height: isTinyScreen
                                                  ? 48
                                                  : (isSmallScreen ? 50 : 56),
                                              child: ElevatedButton(
                                                onPressed: _isLoading
                                                    ? null
                                                    : () async {
                                                        setState(() =>
                                                            _isLoading = true);
                                                        try {
                                                          final user =
                                                              await authService
                                                                  .signInWithGoogle();
                                                          if (user == null &&
                                                              mounted) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Failed to sign in with Google',
                                                                  style: GoogleFonts
                                                                      .poppins(),
                                                                ),
                                                                backgroundColor:
                                                                    Colors.red
                                                                        .shade400,
                                                                behavior:
                                                                    SnackBarBehavior
                                                                        .floating,
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        } finally {
                                                          if (mounted) {
                                                            setState(() =>
                                                                _isLoading =
                                                                    false);
                                                          }
                                                        }
                                                      },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      Colors.grey.shade800,
                                                  elevation: 8,
                                                  shadowColor: Colors.black
                                                      .withOpacity(0.3),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        isTinyScreen ? 12 : 16,
                                                  ),
                                                ),
                                                child: _isLoading
                                                    ? Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              valueColor:
                                                                  AlwaysStoppedAnimation<
                                                                      Color>(
                                                                Colors.grey
                                                                    .shade600,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Flexible(
                                                            child: Text(
                                                              'Signing in...',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: isTinyScreen
                                                                    ? 13
                                                                    : (isSmallScreen
                                                                        ? 14
                                                                        : 16),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Image.asset(
                                                            'assets/google_logo.png',
                                                            width: isTinyScreen
                                                                ? 18
                                                                : 20,
                                                            height: isTinyScreen
                                                                ? 18
                                                                : 20,
                                                            errorBuilder: (context,
                                                                    error,
                                                                    stackTrace) =>
                                                                Icon(
                                                                    Icons.login,
                                                                    size: isTinyScreen
                                                                        ? 18
                                                                        : 20),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Flexible(
                                                            child: Text(
                                                              isTinyScreen
                                                                  ? 'Sign in with Google'
                                                                  : 'Sign in with Google',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: isTinyScreen
                                                                    ? 13
                                                                    : (isSmallScreen
                                                                        ? 14
                                                                        : 16),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
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

                            // Bottom Spacer
                            SizedBox(height: isSmallScreen ? 30 : 50),

                            // Footer
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: isSmallScreen ? 8.0 : 16.0,
                              ),
                              child: Text(
                                'Your digital business card solution',
                                style: GoogleFonts.poppins(
                                  fontSize: isSmallScreen ? 11 : 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
