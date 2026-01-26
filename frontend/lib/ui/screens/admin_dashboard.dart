import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<void> _handleBackup(BuildContext context, String teamId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('backupToSheets')
          .call({
            'teamId': teamId,
            'sheetId': 'USER_SPREADSHEET_ID', // In production, let user input or config
          });

      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup successful! ${result.data['count']} tasks exported to Google Sheets.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel', style: AppTextStyles.subHeading)),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Team Management', style: AppTextStyles.subHeading),
            const SizedBox(height: 16),
            const Text('As an admin, you can export all team data directly to Google Sheets.', style: AppTextStyles.body),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _handleBackup(context, auth.user?.teamId ?? 'default-team'),
              icon: const Icon(Icons.table_chart),
              label: const Text('Backup to Google Sheets'),
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
