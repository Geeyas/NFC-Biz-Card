import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/card_customization_service.dart' as customization;
import '../widgets/animated_gradient_container.dart';

class CardCustomizationScreen extends StatefulWidget {
  const CardCustomizationScreen({super.key});

  @override
  _CardCustomizationScreenState createState() =>
      _CardCustomizationScreenState();
}

class _CardCustomizationScreenState extends State<CardCustomizationScreen>
    with TickerProviderStateMixin {
  List<customization.CardTheme> _themes = [];
  customization.CardTheme? _selectedTheme;
  bool _isCustomizing = false;

  // Custom theme properties
  List<Color> _customGradientColors = [
    const Color(0xFF667eea),
    const Color(0xFF764ba2),
  ];
  Color _customTextColor = Colors.white;
  Color _customAccentColor = const Color(0xFF8e9aff);
  String _customFontFamily = 'Roboto';
  double _customCardRadius = 16.0;
  bool _customHasGlassEffect = false;

  late AnimationController _previewController;
  late Animation<double> _previewAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadThemes();
  }

  void _initializeAnimations() {
    _previewController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _previewAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _previewController, curve: Curves.easeInOut),
    );
    _previewController.repeat(reverse: true);
  }

  Future<void> _loadThemes() async {
    final themes =
        await customization.CardCustomizationService.getSavedThemes();
    final selectedTheme =
        await customization.CardCustomizationService.getSelectedTheme();
    setState(() {
      _themes = themes;
      _selectedTheme = selectedTheme;
    });
  }

  Future<void> _selectTheme(customization.CardTheme theme) async {
    await customization.CardCustomizationService.setSelectedTheme(theme.id);
    setState(() {
      _selectedTheme = theme;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Theme "${theme.name}" selected!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _startCustomTheme() {
    setState(() {
      _isCustomizing = true;
    });
  }

  Future<void> _saveCustomTheme() async {
    final customTheme = customization.CardTheme(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Custom Theme',
      gradientColors: _customGradientColors,
      textColor: _customTextColor,
      accentColor: _customAccentColor,
      fontFamily: _customFontFamily,
      cardRadius: _customCardRadius,
      hasGlassEffect: _customHasGlassEffect,
    );

    await customization.CardCustomizationService.saveCustomTheme(customTheme);
    await customization.CardCustomizationService.setSelectedTheme(
        customTheme.id);

    setState(() {
      _themes.add(customTheme);
      _selectedTheme = customTheme;
      _isCustomizing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom theme saved and applied!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customize Your Card',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        actions: [
          if (_isCustomizing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveCustomTheme,
            ),
        ],
      ),
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Preview
                AnimationConfiguration.staggeredList(
                  position: 0,
                  duration: const Duration(milliseconds: 600),
                  child: SlideAnimation(
                    verticalOffset: -50.0,
                    child: FadeInAnimation(
                      child: _buildLivePreview(),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Theme Selection or Custom Theme Creator
                if (!_isCustomizing) ...[
                  AnimationConfiguration.staggeredList(
                    position: 1,
                    duration: const Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildThemeSelection(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimationConfiguration.staggeredList(
                    position: 2,
                    duration: const Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildCustomThemeButton(),
                      ),
                    ),
                  ),
                ] else ...[
                  AnimationConfiguration.staggeredList(
                    position: 1,
                    duration: const Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildCustomThemeCreator(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreview() {
    final theme = _isCustomizing ? _getCustomTheme() : _selectedTheme;
    if (theme == null) return const SizedBox();

    return GlassmorphicContainer(
      width: double.infinity,
      height: 250,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
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
        child: Column(
          children: [
            Text(
              'Live Preview',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: AnimatedBuilder(
                animation: _previewAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_previewAnimation.value * 0.05),
                    child: _buildBusinessCardPreview(theme),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessCardPreview(customization.CardTheme theme) {
    Widget cardContent = Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
        borderRadius: BorderRadius.circular(theme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: theme.gradientColors.first.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Icon(Icons.person, color: theme.textColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sample Business',
                        style: GoogleFonts.getFont(
                          theme.fontFamily,
                          color: theme.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'John Doe',
                        style: GoogleFonts.getFont(
                          theme.fontFamily,
                          color: theme.textColor.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.email, color: theme.accentColor, size: 16),
                const SizedBox(width: 5),
                Text(
                  'john@sample.com',
                  style: GoogleFonts.getFont(
                    theme.fontFamily,
                    color: theme.textColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.phone, color: theme.accentColor, size: 16),
                const SizedBox(width: 5),
                Text(
                  '+1 234 567 8900',
                  style: GoogleFonts.getFont(
                    theme.fontFamily,
                    color: theme.textColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (theme.hasGlassEffect) {
      return GlassmorphicContainer(
        width: double.infinity,
        height: 150,
        borderRadius: theme.cardRadius,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          colors: theme.gradientColors.map((c) => c.withOpacity(0.3)).toList(),
        ),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.2),
          ],
        ),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildThemeSelection() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 600,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a Theme',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.5,
              ),
              itemCount: _themes.length,
              itemBuilder: (context, index) {
                final theme = _themes[index];
                final isSelected = _selectedTheme?.id == theme.id;

                return GestureDetector(
                  onTap: () => _selectTheme(theme),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.gradientColors.first.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isSelected)
                            const Align(
                              alignment: Alignment.topRight,
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          const Spacer(),
                          Text(
                            theme.name,
                            style: GoogleFonts.poppins(
                              color: theme.textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            theme.fontFamily,
                            style: GoogleFonts.poppins(
                              color: theme.textColor.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomThemeButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _startCustomTheme,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF667eea),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.palette),
            const SizedBox(width: 10),
            Text(
              'Create Custom Theme',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomThemeCreator() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 800,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Custom Theme',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Gradient Colors
            _buildColorPicker(
              'Primary Color',
              _customGradientColors[0],
              (color) => setState(() => _customGradientColors[0] = color),
            ),
            const SizedBox(height: 15),
            _buildColorPicker(
              'Secondary Color',
              _customGradientColors[1],
              (color) => setState(() => _customGradientColors[1] = color),
            ),
            const SizedBox(height: 15),
            _buildColorPicker(
              'Text Color',
              _customTextColor,
              (color) => setState(() => _customTextColor = color),
            ),
            const SizedBox(height: 15),
            _buildColorPicker(
              'Accent Color',
              _customAccentColor,
              (color) => setState(() => _customAccentColor = color),
            ),

            const SizedBox(height: 20),

            // Card Radius Slider
            Text(
              'Card Radius: ${_customCardRadius.toInt()}px',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Slider(
              value: _customCardRadius,
              min: 0,
              max: 30,
              divisions: 30,
              activeColor: Colors.white,
              inactiveColor: Colors.white.withOpacity(0.3),
              onChanged: (value) => setState(() => _customCardRadius = value),
            ),

            const SizedBox(height: 20),

            // Glass Effect Toggle
            Row(
              children: [
                Text(
                  'Glass Effect',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _customHasGlassEffect,
                  activeColor: Colors.white,
                  onChanged: (value) =>
                      setState(() => _customHasGlassEffect = value),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isCustomizing = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveCustomTheme,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF667eea),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('Save Theme'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(
      String label, Color currentColor, Function(Color) onColorChanged) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _showColorPicker(currentColor, onColorChanged),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPicker(Color currentColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: onColorChanged,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  customization.CardTheme _getCustomTheme() {
    return customization.CardTheme(
      id: 'custom_preview',
      name: 'Custom Preview',
      gradientColors: _customGradientColors,
      textColor: _customTextColor,
      accentColor: _customAccentColor,
      fontFamily: _customFontFamily,
      cardRadius: _customCardRadius,
      hasGlassEffect: _customHasGlassEffect,
    );
  }
}
