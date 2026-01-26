import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: AppTextStyles.subHeading),
        automaticallyImplyLeading: false,
      ),
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
                final distribution = (data['priorityDistribution'] as Map<dynamic, dynamic>) ?? {};
                
                return Column(
                  children: [
                    GridView.count(
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
                    ),
                    const SizedBox(height: 32),
                    const Text('Priority Distribution', style: AppTextStyles.subHeading),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(child: _buildPieChart(distribution)),
                          const SizedBox(width: 32),
                          _buildLegend(),
                        ],
                      ),
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
            Wrap(
              spacing: 16,
              children: [
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
                ElevatedButton.icon(
                  onPressed: () => _showColorSettings(context, auth),
                  icon: const Icon(Icons.palette),
                  label: const Text('Customize Colors (Pro)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    backgroundColor: Colors.purple.shade100,
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<dynamic, dynamic> distribution) {
    if (distribution.isEmpty) return const Center(child: Text('No Data'));

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: List.generate(5, (i) {
          final priority = i + 1;
          final count = distribution[priority.toString()] ?? distribution[priority] ?? 0;
          final double value = (count as num).toDouble();
          
          return PieChartSectionData(
            color: getPriorityColor(priority, context.read<AuthProvider>().customColors), // Use dynamic color
            value: value,
            title: value > 0 ? '${value.toInt()}' : '',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
          );
        }),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final p = i + 1;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 12, height: 12, color: getPriorityColor(p, context.read<AuthProvider>().customColors)),
              const SizedBox(width: 8),
              Text('Priority $p'),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _handleBackup(BuildContext context, String teamId) async {
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('backupToSheets').call({'teamId': teamId});
      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup successful!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _handleCSVExport(BuildContext context, String teamId) async {
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('exportTeamToCSV').call({'teamId': teamId});
      if (result.data['csv'] != null) {
        print('CSV Data: ${result.data['csv']}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV Exported!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV Export failed: $e')));
    }
  }

  void _showColorSettings(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context, 
      builder: (context) => _ColorPicker(teamId: auth.user?.teamId ?? 'default-team')
    );
  }
}

class _ColorPicker extends StatefulWidget {
  final String teamId;
  const _ColorPicker({required this.teamId});

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  // Predefined cool palettes
  final List<Color> _palette = [
    const Color(0xFFE8F5E9), const Color(0xFFE3F2FD), const Color(0xFFFFFDE7), const Color(0xFFFFF3E0), const Color(0xFFFCE4EC), // Original
    const Color(0xFFB2EBF2), const Color(0xFFB3E5FC), const Color(0xFFC5CAE9), const Color(0xFFD1C4E9), const Color(0xFFF8BBD0), // Cool Blue/Purple
    const Color(0xFFFFCCBC), const Color(0xFFFFAB91), const Color(0xFFFF8A65), const Color(0xFFFBE9E7), const Color(0xFFFF5722), // Warm Orange
  ];
  
  // For MVP, enable overriding specific Priority 5 color (most important)
  Color _selectedColor = const Color(0xFFFCE4EC); 

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize Priority 5 Color'),
      content: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _palette.map((color) => GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: Container(
              width: 40, 
              height: 40, 
              decoration: BoxDecoration(
                color: color, 
                shape: BoxShape.circle,
                border: _selectedColor == color ? Border.all(color: Colors.black, width: 2) : null
              ),
            ),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            // Save to Firestore 'teams' doc
            await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).set({
              'customColors': {
                '5': _selectedColor.value // Save Priority 5 override
              }
            }, SetOptions(merge: true));
            Navigator.pop(context);
          }, 
          child: const Text('Save')
        )
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

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
