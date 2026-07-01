import 'package:flutter/material.dart';

import '../core/profile_service.dart';
import '../models/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _service = ProfileService();

  late TextEditingController nameController;
  late TextEditingController photoController;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.profile.name);

    photoController = TextEditingController(text: widget.profile.photoUrl);
  }

  @override
  void dispose() {
    nameController.dispose();
    photoController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    setState(() {
      loading = true;
    });

    await _service.updateProfile(
      name: nameController.text.trim(),
      photoUrl: photoController.text.trim(),
    );

    setState(() {
      loading = false;
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            const SizedBox(height: 20),

            // TextField(
            //   controller: photoController,
            //   decoration: const InputDecoration(
            //     labelText: "Avatar URL",
            //   ),
            // ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: loading ? null : saveProfile,

                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
