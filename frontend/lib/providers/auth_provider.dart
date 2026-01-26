import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart' as model;

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(clientId: 'mock-client-id.apps.googleusercontent.com');

  User? _firebaseUser;
  model.User? _user;

  model.User? get user => _user;
  bool get isAuthenticated => _firebaseUser != null;
  
  // Dynamic Color System (Pro)
  Map<int, Color>? _customColors;
  Map<int, Color>? get customColors => _customColors;

  AuthProvider() {
    _auth.userChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _firebaseUser = firebaseUser;
    if (firebaseUser != null) {
      try {
        // Fetch detailed profile from Firestore (Role, Team ID, etc.)
        final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          _user = model.User.fromJson({
            ...data,
            'id': firebaseUser.uid,
            'email': data['email'] ?? firebaseUser.email ?? '', 
            'displayName': data['displayName'] ?? firebaseUser.displayName ?? 'User',
          });
        } else {
          // Doc missing? Create it now (Self-Repair)
          final newUser = model.User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            displayName: firebaseUser.displayName ?? 'User',
            role: 'member',
          );
          
          await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
             'email': newUser.email,
             'displayName': newUser.displayName,
             'role': newUser.role,
             'createdAt': FieldValue.serverTimestamp(),
          });
          
          _user = newUser;
        }
      } catch (e) {
        print('Error fetching/creating user profile: $e');
        // Fallback on error (still create in-memory user so app doesn't crash)
        _user = model.User(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? 'User',
          role: 'member',
        );
      }
      
      // Auto-Create Team if Missing (Self-Healing)
      if (_user?.teamId == null) {
        try {
          print('User has no team. Auto-creating Personal Team...');
          final teamName = "${_user?.displayName ?? 'My'}'s Team";
          await createTeam(teamName); 
        } catch (e) {
          print('Error auto-creating team: $e');
        }
      }

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

  Future<String?> registerWithEmail(String email, String password, String displayName) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      if (cred.user != null) {
        // Update Auth Profile
        await cred.user!.updateDisplayName(displayName);
        await cred.user!.reload(); // Force reload to get updated profile
        _onAuthStateChanged(_auth.currentUser); // Manually trigger update

        try {
           await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
            'email': email,
            'displayName': displayName, // Save actual name
            'role': 'member',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (dbError) {
          print('Error creating user profile in Firestore (Ignored): $dbError');
        }
      }
      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'already-in-use';
      } else if (e.code == 'weak-password') {
        return 'weak-password';
      }
      return e.message;
    } catch (e) {
      print('Registration error: $e');
      return 'Unknown error occurred: $e';
    }
  }

  Future<bool> signInWithGoogle() async {
     // Check if we are using the mock ID (which will fail)
     if (_googleSignIn.clientId != null && _googleSignIn.clientId!.startsWith('mock-')) {
       // print("Google Sign-In: Mock Client ID detected. Skipping auth to prevent 401.");
       return false; 
     }

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

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
       // Update lastLoginAt
      if (_auth.currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).set({
          'email': _auth.currentUser!.email,
          'displayName': _auth.currentUser!.displayName ?? email.split('@').first,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      print('Email Sign-In error: $e');
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
      // Use set(merge: true) to ensure it works even if user doc was missing
      await FirebaseFirestore.instance.collection('users').doc(_user!.id).set({
        'teamId': teamRef.id,
        'role': 'admin' 
      }, SetOptions(merge: true));

      // Update local state immediately
      _user = _user!.copyWith(teamId: teamRef.id, role: 'admin');
      _syncTeamSettings(); // Start listening to new team
      notifyListeners();
      
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
