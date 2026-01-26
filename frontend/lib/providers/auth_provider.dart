import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart' as model;

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _firebaseUser;
  model.User? _user;

  model.User? get user => _user;
  bool get isAuthenticated => _firebaseUser != null;
  
  // Dynamic Color System (Pro)
  Map<int, Color>? _customColors;
  Map<int, Color>? get customColors => _customColors;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _firebaseUser = firebaseUser;
    if (firebaseUser != null) {
      _user = model.User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'User',
        role: 'member', // Default role; fetch from Firestore in production
      );
      _syncTeamSettings(); // Fetch Pro settings
    } else {
      _user = null;
      _customColors = null;
    }
    notifyListeners();
  }

  void _syncTeamSettings() {
     // Listen to Team Document for "customColors" settings
    FirebaseFirestore.instance
        .collection('teams')
        .doc(_user?.teamId ?? 'default-team') 
        .snapshots()
        .listen((snapshot) {
           if (snapshot.exists && snapshot.data()!.containsKey('customColors')) {
             final data = snapshot.data()!['customColors'] as Map<String, dynamic>;
             _customColors = data.map((key, value) => MapEntry(int.parse(key), Color(value)));
             notifyListeners();
           }
        });
  }

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      
      // Update lastLoginAt
      if (_auth.currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).set({
          'email': _auth.currentUser!.email,
          'displayName': _auth.currentUser!.displayName,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return true;
    } catch (e) {
      print('Google Sign-In error: $e');
      return false;
    }
  }

  // --- Team Management Spec ---
  Future<String?> createTeam(String teamName) async {
    if (_user == null) return null;
    try {
      final teamRef = FirebaseFirestore.instance.collection('teams').doc();
      await teamRef.set({
        'name': teamName,
        'adminUid': _user!.id,
        'createdAt': FieldValue.serverTimestamp(),
        'plan': 'free',
        'stats': {'totalCount': 0, 'totalCompleted': 0}
      });
      // Optionally update user's teamId
      await FirebaseFirestore.instance.collection('users').doc(_user!.id).update({
        'teamId': teamRef.id,
        'role': 'admin' 
      });
      
      return teamRef.id;
    } catch (e) {
      print('Create Team Error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
