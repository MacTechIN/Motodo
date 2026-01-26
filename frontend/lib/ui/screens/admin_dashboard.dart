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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Team Health', style: AppTextStyles.subHeading),
            const SizedBox(height: 16),
            FutureBuilder<HttpsCallableResult>(
              future: FirebaseFunctions.instance.httpsCallable('getAdminDashboardMetrics').call({
                'teamId': auth.user?.teamId ?? 'default-team',
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error loading metrics: ${snapshot.error}');
                }
                
                final data = snapshot.data!.data as Map<String, dynamic>;
                return GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MetricCard(
                      label: 'Active Rate (24h)', 
                      value: '${data['activeUserCount']}', 
                      icon: Icons.people, 
                      color: Colors.blue
                    ),
                    _MetricCard(
                      label: 'Completion Rate', 
                      value: '${data['completionRate']}%', 
                      icon: Icons.check_circle, 
                      color: Colors.green
                    ),
                    _MetricCard(
                      label: 'Urgent Tasks (P5)', 
                      value: '${data['urgentCount']}', 
                      icon: Icons.priority_high, 
                      color: Colors.red
                    ),
                    _MetricCard(
                      label: 'Backup Pending', 
                      value: '${data['backupPendingCount']}', 
                      icon: Icons.backup, 
                      color: Colors.orange
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),
            const Text('Data Management', style: AppTextStyles.subHeading),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _handleBackup(context, auth.user?.teamId ?? 'default-team'),
              icon: const Icon(Icons.table_chart),
              label: const Text('Backup to Google Sheets'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                backgroundColor: AppColors.priority4,
                foregroundColor: AppColors.textPrimary,
              ),
            ElevatedButton.icon(
              onPressed: () => _handleCSVExport(context, auth.user?.teamId ?? 'default-team'),
              icon: const Icon(Icons.file_download),
              label: const Text('Download Team CSV'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                backgroundColor: AppColors.priority5,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCSVExport(BuildContext context, String teamId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('exportTeamToCSV')
          .call({'teamId': teamId});

      if (result.data['csv'] != null) {
        // In a real app, use a file picker or save utility
        print('CSV Data received: ${result.data['csv']}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV Exported! (Check console for raw data)')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV Export failed: $e')),
      );
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label, 
    required this.value, 
    required this.icon, 
    required this.color
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
