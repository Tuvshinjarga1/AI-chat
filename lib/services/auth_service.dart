import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aichat/models/user_model.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static UserModel? _currentUser;
  static const String _userKey = 'current_user';

  static UserModel? get currentUser => _currentUser;

  static Future<void> initialize() async {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _fetchUserData(firebaseUser.uid);
      } else {
        _currentUser = null;
      }
    });
  }

  static Future<void> _fetchUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        _currentUser = UserModel.fromFirestore(userDoc);
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  static Future<UserModel?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      print('Attempting to register user: $email');
      // Create user with email and password in Firebase Auth
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = userCredential.user;
      print('User created in Firebase Auth: ${firebaseUser?.uid}');

      if (firebaseUser == null) {
        throw Exception('Бүртгэл үүсгэхэд алдаа гарлаа');
      }

      // Update display name in Firebase Auth
      await firebaseUser.updateDisplayName(displayName);

      // Create user document in Firestore
      final newUser = UserModel(
        id: firebaseUser.uid,
        email: email,
        displayName: displayName,
        isAdmin: false,
        createdAt: DateTime.now(),
        photoUrl: firebaseUser.photoURL,
      );

      // Store user profile in Firestore
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(newUser.toMap());

      print('User created successfully in Firestore');
      _currentUser = newUser;

      return newUser;
    } on FirebaseAuthException catch (e) {
      print(
          'Firebase Auth Exception during registration: ${e.code}, ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Ийм и-мэйл хаягтай хэрэглэгч бүртгэлтэй байна';
          break;
        case 'weak-password':
          errorMessage = 'Нууц үг хэтэрхий сул байна';
          break;
        case 'invalid-email':
          errorMessage = 'И-мэйл хаяг буруу байна';
          break;
        case 'operation-not-allowed':
          errorMessage = 'И-мэйл/нууц үгээр бүртгүүлэх боломжгүй байна';
          break;
        case 'network-request-failed':
          errorMessage =
              'Сүлжээний алдаа гарлаа. Интернэт холболтоо шалгана уу';
          break;
        default:
          errorMessage = 'Бүртгэл үүсгэхэд алдаа гарлаа: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('Unexpected error during registration: $e');
      throw Exception('Бүртгэл үүсгэхэд тодорхойгүй алдаа гарлаа: $e');
    }
  }

  static Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      print('Attempting to login user: $email');
      // Sign in with email and password using Firebase Auth
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = userCredential.user;
      print('User signed in with Firebase Auth: ${firebaseUser?.uid}');

      if (firebaseUser == null) {
        throw Exception('Нэвтрэхэд алдаа гарлаа');
      }

      // Get user profile from Firestore
      await _fetchUserData(firebaseUser.uid);
      print('Fetched user data from Firestore: ${_currentUser != null}');

      if (_currentUser == null) {
        print(
            'User exists in Auth but not in Firestore, creating Firestore profile');
        // User exists in Auth but not in Firestore, create Firestore profile
        final newUser = UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? email,
          displayName: firebaseUser.displayName ?? 'Хэрэглэгч',
          isAdmin: false,
          createdAt: DateTime.now(),
          photoUrl: firebaseUser.photoURL,
        );

        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(newUser.toMap());
        _currentUser = newUser;
        print('Created new user profile in Firestore');
      }

      return _currentUser;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception during login: ${e.code}, ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Ийм и-мэйл хаягтай хэрэглэгч олдсонгүй';
          break;
        case 'wrong-password':
          errorMessage = 'Нууц үг буруу байна';
          break;
        case 'invalid-email':
          errorMessage = 'И-мэйл хаяг буруу байна';
          break;
        case 'user-disabled':
          errorMessage = 'Энэ хэрэглэгч идэвхгүй болсон байна';
          break;
        case 'network-request-failed':
          errorMessage =
              'Сүлжээний алдаа гарлаа. Интернэт холболтоо шалгана уу';
          break;
        default:
          errorMessage = 'Нэвтрэхэд алдаа гарлаа: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('Unexpected error during login: $e');
      throw Exception('Нэвтрэхэд тодорхойгүй алдаа гарлаа: $e');
    }
  }

  static Future<void> logout() async {
    try {
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Ийм и-мэйл хаягтай хэрэглэгч олдсонгүй';
          break;
        case 'invalid-email':
          errorMessage = 'И-мэйл хаяг буруу байна';
          break;
        default:
          errorMessage =
              'Нууц үг шинэчлэх хүсэлт илгээхэд алдаа гарлаа: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('Reset password error: $e');
      rethrow;
    }
  }

  // Add admin users for initial setup (keep this method but update to use Firebase Auth)
  static Future<void> setupInitialAdmins() async {
    try {
      final adminEmail = 'admin@gmail.com';
      final adminPassword = '1234qwer';

      // Check if admin already exists in Firestore
      final adminsQuery = await _firestore
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();

      if (adminsQuery.docs.isEmpty) {
        try {
          // Try to create the admin user in Firebase Auth
          final UserCredential userCredential =
              await _auth.createUserWithEmailAndPassword(
            email: adminEmail,
            password: adminPassword,
          );

          final User? firebaseUser = userCredential.user;

          if (firebaseUser != null) {
            await firebaseUser.updateDisplayName('Админ');

            // Create admin user in Firestore
            final adminUser = UserModel(
              id: firebaseUser.uid,
              email: adminEmail,
              displayName: 'Админ',
              isAdmin: true,
              createdAt: DateTime.now(),
            );

            await _firestore
                .collection('users')
                .doc(firebaseUser.uid)
                .set(adminUser.toMap());
            print('Admin user created');
          }
        } on FirebaseAuthException catch (e) {
          // If admin already exists in Auth but not in Firestore
          if (e.code == 'email-already-in-use') {
            try {
              // Try to sign in with the admin credentials
              final UserCredential userCredential =
                  await _auth.signInWithEmailAndPassword(
                email: adminEmail,
                password: adminPassword,
              );

              final User? firebaseUser = userCredential.user;

              if (firebaseUser != null) {
                // Create admin user in Firestore
                final adminUser = UserModel(
                  id: firebaseUser.uid,
                  email: adminEmail,
                  displayName: 'Админ',
                  isAdmin: true,
                  createdAt: DateTime.now(),
                );

                await _firestore
                    .collection('users')
                    .doc(firebaseUser.uid)
                    .set(adminUser.toMap());
                print('Admin user created in Firestore');

                // Sign out after setup
                await _auth.signOut();
              }
            } catch (signInError) {
              print('Error signing in as admin: $signInError');
            }
          } else {
            print('Error creating admin: ${e.message}');
          }
        }
      }
    } catch (e) {
      print('Error setting up admin: $e');
    }
  }
}
