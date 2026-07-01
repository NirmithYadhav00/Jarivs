import 'package:flutter/material.dart';

import '../core/profile_service.dart';
import '../models/user_profile.dart';
import '../ui/edit_profile_screen.dart';
import '../auth/auth_service.dart';

class ProfileHeader extends StatelessWidget {
  ProfileHeader({super.key});

  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileService.streamUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const ListTile(
            title: Text(
              "No Profile",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final user = snapshot.data!;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            ListTile(
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.blueAccent,
                backgroundImage: user.photoUrl.isNotEmpty
                    ? NetworkImage(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : "L",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),

              title: Text(
                user.name.isEmpty ? "Lucky User" : user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              subtitle: Text(
                user.email,
                style: const TextStyle(color: Colors.white70),
              ),

              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(profile: user),
                    ),
                  );
                },
              ),
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await _authService.logout();
              },
            ),
          ],
        );
      },
    );
  }
}