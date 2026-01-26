import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Sign Up

  // ... (Google Login omitted for brevity, same as before)
  void _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final success = await context.read<AuthProvider>().signInWithGoogle();
    setState(() => _isLoading = false);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Login is not configured yet. Please use Email/Password.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleSubmit() async {
    if (_isLogin) {
      _handleLogin();
    } else {
      _handleSignUp();
    }
  }

  void _handleLogin() async {
     if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email and password.')));
      return;
    }
    setState(() => _isLoading = true);
    final success = await context.read<AuthProvider>().signInWithEmail(_emailController.text, _passwordController.text);
    setState(() => _isLoading = false);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed. Check your password.')));
    }
  }

  void _handleSignUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _teamNameController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields (Name, Team, Email, Password).')));
      return;
    }

    setState(() => _isLoading = true);
    
    // 1. Create User with Name
    final errorMsg = await context.read<AuthProvider>().registerWithEmail(
      _emailController.text, 
      _passwordController.text,
      _nameController.text // Pass Name
    );
    
    if (errorMsg != null) {
      setState(() => _isLoading = false);
      if (mounted) {
         if (errorMsg == 'already-in-use') {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Email already in use. Please login.')));
         } else if (errorMsg == 'weak-password') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Password must be at least 6 characters.')));
         } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $errorMsg')));
         }
      }
      return;
    }

    // 2. Create Team 
    await context.read<AuthProvider>().createTeam(_teamNameController.text);

    setState(() => _isLoading = false);
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team Account Created! Welcome!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Motodo', style: AppTextStyles.heading, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('B2B Collaborative Task Management', style: AppTextStyles.body, textAlign: TextAlign.center),
              const SizedBox(height: 48),
              
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Your Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _teamNameController,
                      decoration: const InputDecoration(labelText: 'Team Name', border: OutlineInputBorder()), // Ensure this is not 'Default Team'
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.priority5,
                  foregroundColor: AppColors.textPrimary,
                ),
                child: Text(_isLogin ? 'Login' : 'Create Team Account'),
              ),
              const SizedBox(height: 16),
              if (_isLogin) ...[
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: const Icon(Icons.login), 
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextButton(
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(_isLogin ? 'Create a new team account' : 'Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
