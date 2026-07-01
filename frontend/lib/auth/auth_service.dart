import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current User
  User? get currentUser => _auth.currentUser;

  // Auth State
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
        await _firestore.collection("users").doc(user.uid).set({
          "uid": user.uid,
          "email": user.email,
          "createdAt": FieldValue.serverTimestamp(),
          "lastLogin": FieldValue.serverTimestamp(),
          "displayName": "",
          "photoUrl": "",
        });
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

      if (credential.user != null) {
        await _firestore
            .collection("users")
            .doc(credential.user!.uid)
            .update({
          "lastLogin": FieldValue.serverTimestamp(),
        });
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
      await _auth.sendPasswordResetEmail(
        email: email,
      );
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
    await _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .update(data);
  }
}