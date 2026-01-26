import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('Building SettingsScreen'); // DEBUG
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: AppTextStyles.heading),
              const SizedBox(height: 32),
              
              // Profile Section
              const Text('Profile', style: AppTextStyles.subHeading),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(user?.displayName?.substring(0, 1).toUpperCase() ?? 'U', 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                ),
                title: Text(user?.displayName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
              ),
              
              const SizedBox(height: 32),
              
              // Team Section
              const Text('Team', style: AppTextStyles.subHeading),
              const SizedBox(height: 16),
              if (user?.teamId == null)
                _buildSettingItem(Icons.group_work, 'Team Name', 'No Team Assigned')
              else
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('teams').doc(user!.teamId).get(),
                  builder: (context, snapshot) {
                    String displayValue = 'Loading...';
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      displayValue = 'Loading...';
                    } else if (snapshot.hasError) {
                       print('Settings Team Load Error: ${snapshot.error}'); // DEBUG
                       displayValue = 'Error loading team';
                    } else if (!snapshot.hasData || !snapshot.data!.exists) {
                      print('Settings: Team doc ${user!.teamId} does not exist'); // DEBUG
                      displayValue = 'Team Not Found';
                    } else {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      displayValue = data?['name'] ?? 'Unnamed Team';
                    }
                    
                    return _buildSettingItem(Icons.group_work, 'Team Name', displayValue); 
                  },
                ),
              _buildSettingItem(Icons.verified_user, 'Role', user?.role ?? 'Member'),
              
              const Spacer(),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<TodoProvider>().clear(); // Stop streams logs
                    context.read<AuthProvider>().logout();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Log Out', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.black54),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
