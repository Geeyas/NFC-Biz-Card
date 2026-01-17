import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CardTheme {
  final String id;
  final String name;
  final List<Color> gradientColors;
  final Color textColor;
  final Color accentColor;
  final String fontFamily;
  final double cardRadius;
  final bool hasGlassEffect;
  final String backgroundPattern;

  CardTheme({
    required this.id,
    required this.name,
    required this.gradientColors,
    required this.textColor,
    required this.accentColor,
    required this.fontFamily,
    this.cardRadius = 16.0,
    this.hasGlassEffect = false,
    this.backgroundPattern = 'none',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gradientColors': gradientColors.map((c) => c.value).toList(),
      'textColor': textColor.value,
      'accentColor': accentColor.value,
      'fontFamily': fontFamily,
      'cardRadius': cardRadius,
      'hasGlassEffect': hasGlassEffect,
      'backgroundPattern': backgroundPattern,
    };
  }

  factory CardTheme.fromJson(Map<String, dynamic> json) {
    return CardTheme(
      id: json['id'],
      name: json['name'],
      gradientColors:
          (json['gradientColors'] as List).map((c) => Color(c as int)).toList(),
      textColor: Color(json['textColor']),
      accentColor: Color(json['accentColor']),
      fontFamily: json['fontFamily'],
      cardRadius: json['cardRadius']?.toDouble() ?? 16.0,
      hasGlassEffect: json['hasGlassEffect'] ?? false,
      backgroundPattern: json['backgroundPattern'] ?? 'none',
    );
  }
}

class CardCustomizationService {
  static const String _key = 'card_themes';

  static List<CardTheme> getDefaultThemes() {
    return [
      CardTheme(
        id: 'professional_blue',
        name: 'Professional Blue',
        gradientColors: [
          const Color(0xFF2196F3),
          const Color(0xFF1976D2),
        ],
        textColor: Colors.white,
        accentColor: const Color(0xFF64B5F6),
        fontFamily: 'Roboto',
      ),
      CardTheme(
        id: 'elegant_purple',
        name: 'Elegant Purple',
        gradientColors: [
          const Color(0xFF9C27B0),
          const Color(0xFF673AB7),
        ],
        textColor: Colors.white,
        accentColor: const Color(0xFFBA68C8),
        fontFamily: 'Roboto',
      ),
      CardTheme(
        id: 'corporate_dark',
        name: 'Corporate Dark',
        gradientColors: [
          const Color(0xFF424242),
          const Color(0xFF212121),
        ],
        textColor: Colors.white,
        accentColor: const Color(0xFF757575),
        fontFamily: 'Roboto',
      ),
      CardTheme(
        id: 'modern_gradient',
        name: 'Modern Gradient',
        gradientColors: [
          const Color(0xFF667eea),
          const Color(0xFF764ba2),
        ],
        textColor: Colors.white,
        accentColor: const Color(0xFF8e9aff),
        fontFamily: 'Roboto',
        hasGlassEffect: true,
      ),
      CardTheme(
        id: 'sunset_glow',
        name: 'Sunset Glow',
        gradientColors: [
          const Color(0xFFFF6B6B),
          const Color(0xFFFFE66D),
        ],
        textColor: Colors.white,
        accentColor: const Color(0xFFFF8E53),
        fontFamily: 'Roboto',
      ),
      CardTheme(
        id: 'ocean_breeze',
        name: 'Ocean Breeze',
        gradientColors: [
          const Color(0xFF00BCD4),
          const Color(0xFF009688),
        ],
        textColor: Colors.white,
        accentColor: const Color(0xFF4DB6AC),
        fontFamily: 'Roboto',
      ),
      CardTheme(
        id: 'forest_green',
        name: 'Forest Green',
        gradientColors: [
          const Color(0xFF4CAF50),
          const Color(0xFF2E7D32),
        ],
        textColor: Colors.white,
        accentColor: const Color(0xFF66BB6A),
        fontFamily: 'Roboto',
      ),
      CardTheme(
        id: 'royal_gold',
        name: 'Royal Gold',
        gradientColors: [
          const Color(0xFFFFD700),
          const Color(0xFFFFA000),
        ],
        textColor: const Color(0xFF3E2723),
        accentColor: const Color(0xFFFFB300),
        fontFamily: 'Roboto',
      ),
    ];
  }

  static Future<List<CardTheme>> getSavedThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themesJson = prefs.getString(_key);

    if (themesJson == null) {
      return getDefaultThemes();
    }

    try {
      final List<dynamic> themesList = jsonDecode(themesJson);
      return themesList.map((json) => CardTheme.fromJson(json)).toList();
    } catch (e) {
      return getDefaultThemes();
    }
  }

  static Future<void> saveThemes(List<CardTheme> themes) async {
    final prefs = await SharedPreferences.getInstance();
    final String themesJson =
        jsonEncode(themes.map((t) => t.toJson()).toList());
    await prefs.setString(_key, themesJson);
  }

  static Future<void> saveCustomTheme(CardTheme theme) async {
    final themes = await getSavedThemes();
    themes.removeWhere((t) => t.id == theme.id);
    themes.add(theme);
    await saveThemes(themes);
  }

  static Future<CardTheme?> getSelectedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeId = prefs.getString('selected_theme_id');

    if (themeId == null) {
      return getDefaultThemes().first;
    }

    final themes = await getSavedThemes();
    return themes.firstWhere(
      (theme) => theme.id == themeId,
      orElse: () => getDefaultThemes().first,
    );
  }

  static Future<void> setSelectedTheme(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme_id', themeId);
  }
}
