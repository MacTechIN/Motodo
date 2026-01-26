import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  // For MVP, backend is at localhost:3000
  final String _baseUrl = 'http://localhost:3000';

  async Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        
        // Fetch profile (for MVP, we assume user data is in the token payload or fetch separately)
        // Here we just mock the user data from response or payload
        _user = User(
          id: 'mock-id',
          email: email,
          displayName: 'User',
          role: 'member',
        );
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  void logout() {
    _user = null;
    _token = null;
    notifyListeners();
  }
}
