import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import '../core/profile_service.dart';
import '../models/user_profile.dart';

class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key});

  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Settings"),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.streamUserProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final profile = snapshot.data!;

          return ListView(
            children: [

              const SizedBox(height: 20),

              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(profile.name.isEmpty
                    ? "Lucky User"
                    : profile.name),
                subtitle: Text(profile.email),
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Edit Profile"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditProfileScreen(profile: profile),
                    ),
                  );
                },
              ),

              SwitchListTile(
                value: true,
                onChanged: (_) {},
                title: const Text("Dark Mode"),
              ),

              ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: const Text("Voice Settings"),
                subtitle: const Text("Coming Soon"),
              ),

              ListTile(
                leading: const Icon(Icons.language),
                title: const Text("Language"),
                subtitle: const Text("English"),
              ),

              const Divider(),

              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  await _authService.logout();

                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}