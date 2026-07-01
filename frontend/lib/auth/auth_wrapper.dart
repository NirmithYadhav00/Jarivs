import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../ui/home_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print("========== AUTH WRAPPER ==========");
        print("Connection: ${snapshot.connectionState}");
        print("Has Data: ${snapshot.hasData}");
        print("User: ${snapshot.data?.email}");

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          print("GOING TO HOME");
          return const HomeScreen();
        }

        print("GOING TO LOGIN");

        return const LoginScreen();
      },
    );
  }
}
