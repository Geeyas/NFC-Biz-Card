import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:cardflow/screens/modern_home_screen.dart';
import 'package:cardflow/screens/login_screen.dart';
import 'package:cardflow/screens/submission_screen.dart';
import 'package:cardflow/screens/card_sharing_hub.dart';
import 'package:cardflow/screens/card_customization_screen.dart';
import 'package:cardflow/screens/business_card.dart';
import 'package:cardflow/services/auth_service.dart';
import 'package:cardflow/services/deep_link_service.dart';
import 'package:cardflow/services/fcm_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  // This is required for the splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('Firebase initialized successfully!');
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }

  try {
    // Initialize App Check (for Android and iOS)
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.safetyNet, // For Android
      // Removed iosProvider as it's not supported in the latest versions
    );
    print('App Check initialized successfully!');
  } catch (e) {
    debugPrint('Error initializing App Check: $e');
  }

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Remove splash screen after initialization
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Remove flutter native splash after the first frame is rendered
    FlutterNativeSplash.remove();
  });

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  final FCMService _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    // Initialize deep linking and FCM after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkService.initialize(context);
      _fcmService.initialize();
      // Start in-app notification listener (works without Cloud Functions!)
      _fcmService.startNotificationListener();
    });
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'CardFlow - Business Card Sharing',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF667eea),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          scaffoldBackgroundColor: Colors.transparent,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthHandler(),
          '/home': (context) => const ModernHomeScreen(),
          '/submissions': (context) => const MySubmissionsScreen(),
          '/sharing': (context) => const CardSharingHub(),
          '/customization': (context) => const CardCustomizationScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle business card route with arguments
          if (settings.name == '/business-card') {
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => BusinessCardScreen(
                  businessName: args['businessName'] ?? '',
                  personName: args['personName'] ?? '',
                  website: args['website'] ?? '',
                  email: args['email'] ?? '',
                  contactNumber: args['contactNumber'] ?? '',
                  image: args['image'] ?? '',
                  themeId: args['themeId'],
                  themeData: args['themeData'],
                  cardId: args['cardId'],
                ),
              );
            }
          }
          return null;
        },
      ),
    );
  }
}

class AuthHandler extends StatelessWidget {
  const AuthHandler({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return StreamBuilder<User?>(
          stream: authService.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              final user = snapshot.data;
              if (user == null) {
                return const LoginScreen();
              }
              return const ModernHomeScreen();
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('An error occurred. Please try again.'),
              );
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }
}
