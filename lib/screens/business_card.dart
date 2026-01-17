import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/card_customization_service.dart' as customization;
import '../services/analytics_service.dart';
import '../services/local_image_service.dart';
import '../widgets/animated_gradient_container.dart';

class BusinessCardScreen extends StatefulWidget {
  final String businessName;
  final String personName;
  final String? website;
  final String email;
  final String contactNumber;
  final String? image;
  final String? themeId;
  final Map<String, dynamic>? themeData;
  final String? cardId;
  final String?
      ownerUsername; // Username of card owner (for analytics tracking)

  const BusinessCardScreen({
    super.key,
    required this.businessName,
    required this.personName,
    this.website,
    required this.email,
    required this.contactNumber,
    this.image,
    this.themeId,
    this.themeData,
    this.cardId,
    this.ownerUsername, // Optional: only set when viewing received cards
  });

  @override
  _BusinessCardScreenState createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  customization.CardTheme? _cardTheme;
  String? _localImagePath;
  final LocalImageService _localImageService = LocalImageService();

  @override
  void initState() {
    super.initState();
    _loadCardTheme();
    _loadLocalImage();

    // Track card view (for owner if ownerUsername is set, otherwise for current user)
    if (widget.cardId != null) {
      AnalyticsService.trackCardView(
        cardId: widget.cardId!,
        userId: widget.ownerUsername, // If null, tracks for current user
      );
      print(
          '📊 Card view tracked for: ${widget.ownerUsername ?? "current user"}');
    }
  }

  Future<void> _loadCardTheme() async {
    // Priority 1: Use themeData if provided (from saved card)
    if (widget.themeData != null) {
      final themeData = widget.themeData!;
      setState(() {
        _cardTheme = customization.CardTheme(
          id: themeData['themeId'] ?? 'professional_blue',
          name: _getThemeName(themeData['themeId'] ?? 'professional_blue'),
          gradientColors: [
            Color(int.parse(themeData['gradientColor1'] ?? 'FF667eea',
                radix: 16)),
            Color(int.parse(themeData['gradientColor2'] ?? 'FF764ba2',
                radix: 16)),
          ],
          textColor:
              Color(int.parse(themeData['textColor'] ?? 'FFFFFFFF', radix: 16)),
          accentColor: Color(
              int.parse(themeData['accentColor'] ?? 'FF667eea', radix: 16)),
          fontFamily: themeData['fontFamily'] ?? 'Poppins',
          cardRadius: (themeData['borderRadius'] ?? 20.0).toDouble(),
          hasGlassEffect: themeData['hasGlassEffect'] ?? true,
        );
      });
    }
    // Priority 2: Use themeId if provided
    else if (widget.themeId != null) {
      final themes =
          await customization.CardCustomizationService.getSavedThemes();
      final theme = themes.firstWhere(
        (t) => t.id == widget.themeId,
        orElse: () =>
            customization.CardCustomizationService.getDefaultThemes().first,
      );
      setState(() {
        _cardTheme = theme;
      });
    }
    // Priority 3: Use selected theme
    else {
      final theme =
          await customization.CardCustomizationService.getSelectedTheme();
      setState(() {
        _cardTheme = theme;
      });
    }
  }

  Future<void> _loadLocalImage() async {
    if (widget.cardId != null) {
      final localPath =
          await _localImageService.getCardImagePath(widget.cardId!);
      if (localPath != null && mounted) {
        setState(() {
          _localImagePath = localPath;
        });
      }
    }
  }

  String _getThemeName(String themeId) {
    final themeNames = {
      'professional_blue': 'Professional Blue',
      'elegant_purple': 'Elegant Purple',
      'corporate_dark': 'Corporate Dark',
      'modern_gradient': 'Modern Gradient',
      'sunset_glow': 'Sunset Glow',
      'ocean_breeze': 'Ocean Breeze',
      'forest_green': 'Forest Green',
      'royal_gold': 'Royal Gold',
    };
    return themeNames[themeId] ?? 'Custom Theme';
  }

  @override
  Widget build(BuildContext context) {
    final theme = _cardTheme ??
        customization.CardCustomizationService.getDefaultThemes().first;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Business Card',
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  // Full Screen Card (Rotated 90°)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: AspectRatio(
                            aspectRatio: 1.6,
                            child: theme.hasGlassEffect
                                ? _buildGlassCard(theme)
                                : _buildRegularCard(theme),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Action Buttons at Bottom (Flexible height)
                  Flexible(
                    flex: 0,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: MediaQuery.of(context).size.height * 0.010,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: _buildActionButtons(theme),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRegularCard(customization.CardTheme theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
        borderRadius: BorderRadius.circular(theme.cardRadius),
      ),
      child: _buildCardContent(theme),
    );
  }

  Widget _buildGlassCard(customization.CardTheme theme) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: double.infinity,
      borderRadius: theme.cardRadius,
      blur: 25,
      alignment: Alignment.center,
      border: 2.5,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: theme.gradientColors.map((c) => c.withOpacity(0.35)).toList(),
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.6),
          Colors.white.withOpacity(0.2),
          Colors.white.withOpacity(0.1),
        ],
      ),
      child: _buildCardContent(theme),
    );
  }

  Widget _buildCardContent(customization.CardTheme theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing based on available space
        final availableHeight = constraints.maxHeight;
        final isSmall = availableHeight < 200;
        final isMedium = availableHeight >= 200 && availableHeight < 280;

        final avatarSize = isSmall ? 85.0 : (isMedium ? 100.0 : 115.0);
        final titleSize = isSmall ? 22.0 : (isMedium ? 26.0 : 30.0);
        final subtitleSize = isSmall ? 13.0 : (isMedium ? 16.0 : 19.0);
        final infoSize = isSmall ? 15.0 : (isMedium ? 18.0 : 20.0);
        final iconSize = isSmall ? 20.0 : (isMedium ? 24.0 : 26.0);
        final padding = isSmall ? 28.0 : (isMedium ? 35.0 : 40.0);

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with image and business name
              Flexible(
                flex: 2,
                child: Row(
                  children: [
                    // Profile Image
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.textColor.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: avatarSize / 2 - 3,
                        backgroundImage: _localImagePath != null
                            ? FileImage(File(_localImagePath!))
                            : (widget.image == null || widget.image!.isEmpty)
                                ? null
                                : NetworkImage(widget.image!) as ImageProvider,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: (_localImagePath == null &&
                                (widget.image == null || widget.image!.isEmpty))
                            ? Icon(Icons.person,
                                color: theme.textColor, size: avatarSize * 0.58)
                            : null,
                      ),
                    ),
                    SizedBox(width: isSmall ? 14 : (isMedium ? 18 : 22)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.businessName,
                            style: GoogleFonts.getFont(
                              theme.fontFamily,
                              color: theme.textColor,
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmall ? 3 : (isMedium ? 5 : 6)),
                          Text(
                            widget.personName,
                            style: GoogleFonts.getFont(
                              theme.fontFamily,
                              color: theme.textColor.withOpacity(0.85),
                              fontSize: subtitleSize,
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
              ),

              SizedBox(height: isSmall ? 10 : (isMedium ? 14 : 16)),

              // Divider
              Container(
                height: 1.5,
                margin: EdgeInsets.symmetric(
                    vertical: isSmall ? 10 : (isMedium ? 12 : 14)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.textColor.withOpacity(0.0),
                      theme.textColor.withOpacity(0.4),
                      theme.textColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),

              // Contact Information - Simple Display
              Flexible(
                flex: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSimpleInfoRow(
                        Icons.email_outlined, widget.email, theme,
                        fontSize: infoSize, iconSize: iconSize),
                    SizedBox(height: isSmall ? 10 : (isMedium ? 12 : 14)),
                    _buildSimpleInfoRow(
                        Icons.phone_outlined, widget.contactNumber, theme,
                        fontSize: infoSize, iconSize: iconSize),
                    if (widget.website != null &&
                        widget.website!.isNotEmpty) ...[
                      SizedBox(height: isSmall ? 10 : (isMedium ? 12 : 14)),
                      _buildSimpleInfoRow(
                          Icons.language_outlined, widget.website!, theme,
                          fontSize: infoSize, iconSize: iconSize),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Simple info display without clickable container
  Widget _buildSimpleInfoRow(
      IconData icon, String value, customization.CardTheme theme,
      {double fontSize = 12.0, double iconSize = 18.0}) {
    return Row(
      children: [
        Icon(
          icon,
          color: theme.textColor.withOpacity(0.8),
          size: iconSize,
        ),
        SizedBox(width: fontSize > 17 ? 16 : 14),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.getFont(
              theme.fontFamily,
              color: theme.textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(customization.CardTheme theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive button size
        final buttonSize = (constraints.maxWidth / 5).clamp(65.0, 73.0);
        final titleSize = (buttonSize / 5.5).clamp(11.0, 13.0);
        final spacing = (buttonSize / 6.5).clamp(7.0, 10.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Actions Title - More Visible
            Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade800,
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: spacing),

            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  onTap: () =>
                      _handleContactTap(Icons.phone, widget.contactNumber),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  size: buttonSize,
                ),
                _buildActionButton(
                  icon: Icons.email,
                  label: 'Email',
                  onTap: () => _handleContactTap(Icons.email, widget.email),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFf093fb), Color(0xFFF5576C)],
                  ),
                  size: buttonSize,
                ),
                if (widget.website != null && widget.website!.isNotEmpty)
                  _buildActionButton(
                    icon: Icons.language,
                    label: 'Website',
                    onTap: () => _handleContactTap(Icons.web, widget.website!),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2ebf91), Color(0xFF8360c3)],
                    ),
                    size: buttonSize,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Gradient gradient,
    required double size,
  }) {
    final iconSize = (size * 0.35).clamp(22.0, 26.0);
    final fontSize = (size * 0.13).clamp(9.0, 10.0);
    final borderRadius = (size * 0.21).clamp(14.0, 16.0);
    final spacing = (size * 0.08).clamp(4.0, 6.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: gradient,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
            SizedBox(height: spacing),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContactTap(IconData icon, String value) async {
    try {
      print('🔵 Handling contact tap - Icon: $icon, Value: $value');

      // Track analytics for owner (if ownerUsername is set) or current user
      if (widget.cardId != null) {
        final username = widget.ownerUsername; // Owner's username or null

        if (icon == Icons.email) {
          await AnalyticsService.trackEmailClick(
            cardId: widget.cardId!,
            userId: username,
          );
          print('✅ Email click tracked for ${username ?? "current user"}');
        } else if (icon == Icons.phone) {
          await AnalyticsService.trackPhoneClick(
            cardId: widget.cardId!,
            userId: username,
          );
          print('✅ Phone click tracked for ${username ?? "current user"}');
        } else if (icon == Icons.web || icon == Icons.language) {
          await AnalyticsService.trackWebsiteClick(
            cardId: widget.cardId!,
            userId: username,
          );
          print('✅ Website click tracked for ${username ?? "current user"}');
        }
      }

      // Launch the appropriate action
      Uri? uri;
      LaunchMode mode = LaunchMode.platformDefault;

      if (icon == Icons.email) {
        uri = Uri(scheme: 'mailto', path: value);
        print('📧 Opening email client for: $value');
      } else if (icon == Icons.phone) {
        uri = Uri(scheme: 'tel', path: value);
        print('📞 Opening phone dialer for: $value');
      } else if (icon == Icons.web || icon == Icons.language) {
        String url = value;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }
        uri = Uri.parse(url);
        mode = LaunchMode.externalApplication;
        print('🌐 Opening browser for: $url');
      }

      if (uri != null) {
        print('🔍 Checking if can launch URL: $uri');
        final canLaunch = await canLaunchUrl(uri);
        print('🔍 Can launch: $canLaunch');

        if (canLaunch) {
          print('🚀 Launching URL...');
          final launched = await launchUrl(uri, mode: mode);
          print('✅ Launch result: $launched');
        } else {
          print('❌ Cannot launch URL');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not launch $value'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('❌ URI is null');
      }
    } catch (e) {
      print('❌ Error handling contact tap: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
