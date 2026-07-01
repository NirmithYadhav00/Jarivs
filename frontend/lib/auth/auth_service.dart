import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==========================================================
  // SIGN UP
  // ==========================================================

  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        print("Creating Firestore user...");

        await _firestore.collection("users").doc(user.uid).set({
          "uid": user.uid,
          "name": "",
          "email": user.email,
          "photoUrl": "",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
          "lastLogin": FieldValue.serverTimestamp(),
        });

        print("Firestore user created successfully");
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        final doc =
            _firestore.collection("users").doc(user.uid);

        final snapshot = await doc.get();

        // If profile doesn't exist, create it
        if (!snapshot.exists) {
          print("User profile not found. Creating...");

          await doc.set({
            "uid": user.uid,
            "name": "",
            "email": user.email,
            "photoUrl": "",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "lastLogin": FieldValue.serverTimestamp(),
          });

          print("Profile created.");
        } else {
          await doc.update({
            "lastLogin": FieldValue.serverTimestamp(),
          });
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> logout() async {
    await _auth.signOut();
  }

  // ==========================================================
  // RESET PASSWORD
  // ==========================================================

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ==========================================================
  // GET USER DATA
  // ==========================================================

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserData() async {
    return await _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .get();
  }

  // ==========================================================
  // UPDATE USER DATA
  // ==========================================================

  Future<void> updateUser(Map<String, dynamic> data) async {
    data["updatedAt"] = FieldValue.serverTimestamp();

    await _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .update(data);
  }
}