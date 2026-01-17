import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cardflow/screens/modern_home_screen.dart';
import 'package:cardflow/screens/login_screen.dart';
import 'package:cardflow/widgets/cardflow_branding.dart';

class SplashScreenWrapper extends StatelessWidget {
  const SplashScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Splash Screen for the initial 2 seconds
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Redirect based on authentication state
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen(); // Redirect to LoginScreen if not logged in
        }
        return const ModernHomeScreen(); // Redirect to ModernHomeScreen if logged in
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use our CardFlow Logo component
            const CardFlowLogo(size: 120),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
            ),
          ],
        ),
      ),
    );
  }
}
