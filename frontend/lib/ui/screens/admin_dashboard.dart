import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<void> _handleBackup(BuildContext context, String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/admin/export-csv'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup data fetched successfully. (CSV Download triggered)')),
        );
        // In actual Web/Desktop, trigger file download here
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup failed. Permission denied.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthProvider>().token;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel', style: AppTextStyles.subHeading)),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Team Management', style: AppTextStyles.subHeading),
            const SizedBox(height: 16),
            const Text('As an admin, you can export all team data for backup and auditing.', style: AppTextStyles.body),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _handleBackup(context, token!),
              icon: const Icon(Icons.download),
              label: const Text('Backup Data (CSV)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                backgroundColor: AppColors.priority4,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
