import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the currently logged-in Firebase user
  User? get currentUser => _auth.currentUser;

  /// Creates a Firestore profile if it doesn't already exist
  Future<void> createUserProfile() async {
    final user = currentUser;

    if (user == null) return;

    final doc =
        _firestore.collection('users').doc(user.uid);

    final snapshot = await doc.get();

    if (!snapshot.exists) {
      final profile = UserProfile(
        uid: user.uid,
        name: user.displayName ?? "Lucky User",
        email: user.email ?? "",
        photoUrl: user.photoURL ?? "",
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      await doc.set(profile.toMap());
    }
  }

  /// Get profile once
  Future<UserProfile?> getUserProfile() async {
    final user = currentUser;

    if (user == null) return null;

    final snapshot =
        await _firestore.collection('users').doc(user.uid).get();

    if (!snapshot.exists) return null;

    return UserProfile.fromMap(snapshot.data()!);
  }

  /// Listen for real-time profile updates
  Stream<UserProfile?> streamUserProfile() {
    final user = currentUser;

    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data()!);
    });
  }

  /// Update profile
  Future<void> updateProfile({
    required String name,
    required String photoUrl,
  }) async {
    final user = currentUser;

    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .update({
      'name': name,
      'photoUrl': photoUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}