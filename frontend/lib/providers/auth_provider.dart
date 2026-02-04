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
  StreamSubscription? _userProfileSub; // Live User Profile Listener
  bool _disposed = false; // Safety guard

  AuthProvider() {
    _auth.userChanges().listen(_onAuthStateChanged);
  }
  
  @override
  void dispose() {
    _disposed = true;
    _teamSettingsSub?.cancel();
    _userProfileSub?.cancel();
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
    _firebaseUser = firebaseUser;
    
    // Always cancel old listener to prevent leaks/conflicts
    _userProfileSub?.cancel();

    if (firebaseUser != null) {
      // 🚀 OPTIMISTIC LOAD: Show Dashboard instantly
      if (_user == null) {
        _user = model.User(
           id: firebaseUser.uid, 
           email: firebaseUser.email ?? '', 
           displayName: firebaseUser.displayName ?? 'User',
           role: 'member',
        );
        notifyListeners(); 
      }

      // 📡 REAL-TIME UPDATE: Auto-refresh when DB changes (e.g. Team Created)
      _userProfileSub = FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .listen((snapshot) {
             if (_disposed) return;

             if (snapshot.exists && snapshot.data() != null) {
               final data = snapshot.data()!;
               
               // Live Update User Model
               _user = model.User.fromJson({
                  ...data,
                  'id': firebaseUser.uid,
                  'email': data['email'] ?? firebaseUser.email ?? '',
                  'displayName': data['displayName'] ?? firebaseUser.displayName ?? 'User',
               });
               
               // Auto-Heal: If Team ID is missing, create one (Background)
               if (_user?.teamId == null) {
                  joinOrCreateTeam("${_user?.displayName ?? 'My'}'s Team", forceCreate: true);
               }

               _syncTeamSettings();
             } else {
               // First Login: Create User Doc
               _updateUserDoc(firebaseUser.uid, {
                  'email': firebaseUser.email ?? '',
                  'displayName': firebaseUser.displayName ?? 'User',
                  'role': 'member',
                  'createdAt': FieldValue.serverTimestamp(),
               });
             }
             notifyListeners(); // Refresh UI with new data
          }, onError: (e) {
             print("User Profile Sync Error: $e");
          });

    } else {
        // Logout Cleanup
        _user = null;
        _customColors = null;
        _teamSettingsSub?.cancel();
        notifyListeners();
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
           await _updateUserDoc(cred.user!.uid, {
            'email': email,
            'displayName': displayName,
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
      
      // Update Profile metadata
      if (_auth.currentUser != null) {
        await _updateUserDoc(_auth.currentUser!.uid, {
          'email': _auth.currentUser!.email,
          'displayName': _auth.currentUser!.displayName,
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
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
       // Update Profile metadata
      if (_auth.currentUser != null) {
        await _updateUserDoc(_auth.currentUser!.uid, {
          'email': _auth.currentUser!.email,
          'displayName': _auth.currentUser!.displayName ?? email.split('@').first,
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      print('Email Sign-In error: $e');
      return false;
    }
  }

  // --- Team Management Spec ---
  // --- Team Management Spec ---
  Future<String?> joinOrCreateTeam(String teamNameInput, {bool forceCreate = false}) async {
    if (_user == null) return null;
    final teamName = teamNameInput.trim();
    
    String teamId = '';
    String role = '';
    
    try {
      bool found = false;

      // 1. Search for existing team (Skip if forcing create)
      if (!forceCreate) {
        try {
          print('Searching for team: $teamName ...');
          final query = await FirebaseFirestore.instance
              .collection('teams')
              .where('name', isEqualTo: teamName)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 3)); // Fast timeout
          
          if (query.docs.isNotEmpty) {
            found = true;
            teamId = query.docs.first.id;
            role = 'member';
            print('Joining existing team: $teamName ($teamId)');
          }
        } catch (e) {
          print('Team search failed/timed out, falling back to create: $e');
        }
      }

      // 2. Create if not found or forced
      if (!found) {
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

      // 3. Update User Profile (Standardized)
      await _updateUserDoc(_user!.id, {
        'teamId': teamId,
        'teamName': teamName,
        'role': role 
      });

      // 4. Update Local State
      _user = _user!.copyWith(teamId: teamId, teamName: teamName, role: role);
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

  /// Standardized User Document Update
  Future<void> _updateUserDoc(String uid, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        data, 
        SetOptions(merge: true)
      );
    } catch (e) {
      print("Error updating user doc: $e");
    }
  }
}
