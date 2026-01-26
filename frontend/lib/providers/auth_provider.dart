import 'dart:async';
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
  
  // bool _isSyncing = false; // Removed lock to allow stream events
  StreamSubscription? _teamSettingsSub;
  bool _disposed = false; // Safety guard

  AuthProvider() {
    _auth.userChanges().listen(_onAuthStateChanged);
  }
  
  @override
  void dispose() {
    _disposed = true;
    _teamSettingsSub?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (_disposed) return;

    try {
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
            // ... (Self Repair Logic SAME as before) ...
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
              await joinOrCreateTeam(teamName); 
           } catch (e) {
              print('Error auto-creating team: $e');
           }
        }

        _syncTeamSettings(); // Fetch Pro settings
      } else {
        _user = null;
        _customColors = null;
        _teamSettingsSub?.cancel();
      }
      notifyListeners();
    } catch (e) {
      print('Auth State Change Error: $e');
    }
  }

  void _syncTeamSettings() {
     if (_user?.teamId == null) return; 
     _teamSettingsSub?.cancel();

    _teamSettingsSub = FirebaseFirestore.instance
        .collection('teams')
        .doc(_user!.teamId) 
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
        // Note: We do NOT call reload() or _onAuthStateChanged() manually here.
        // The auth stream will pick up the changes automatically.
        // This prevents double-execution and race conditions.

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
  Future<String?> joinOrCreateTeam(String teamNameInput) async {
    if (_user == null) return null;
    final teamName = teamNameInput.trim();
    
    try {
      // 1. Search for existing team (Exact Match for now)
      // Todo: Add finding by case-insensitive name if needed later
      final query = await FirebaseFirestore.instance
          .collection('teams')
          .where('name', isEqualTo: teamName)
          .limit(1)
          .get();

      String teamId;
      String role;

      if (query.docs.isNotEmpty) {
        // JOIN Existing Team
        final teamDoc = query.docs.first;
        teamId = teamDoc.id;
        role = 'member';
        print('Joining existing team: $teamName ($teamId)');
      } else {
        // CREATE New Team
        final teamRef = FirebaseFirestore.instance.collection('teams').doc();
        await teamRef.set({
          'name': teamName,
          'adminUid': _user!.id,
          'createdAt': FieldValue.serverTimestamp(),
          'plan': 'free',
          'stats': {'totalCount': 0, 'totalCompleted': 0}
        });
        teamId = teamRef.id;
        role = 'admin';
        print('Creating new team: $teamName ($teamId)');
      }

      // 2. Update User Profile (Safe Merge)
      await FirebaseFirestore.instance.collection('users').doc(_user!.id).set({
        'teamId': teamId,
        'role': role 
      }, SetOptions(merge: true));

      // 3. Update Local State
      _user = _user!.copyWith(teamId: teamId, role: role);
      _syncTeamSettings(); 
      notifyListeners();
      
      return teamId;
    } catch (e) {
      print('Join/Create Team Error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
