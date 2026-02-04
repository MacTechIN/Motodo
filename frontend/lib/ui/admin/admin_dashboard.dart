import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added missing import
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _memberCount = 0;
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMemberCount();
    });
  }

  Future<void> _fetchMemberCount() async {
    final auth = context.read<AuthProvider>();
    final teamId = auth.user?.teamId;
    if (teamId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('teamId', isEqualTo: teamId)
          .count()
          .get();
      
      if (mounted) {
        setState(() {
          _memberCount = snapshot.count ?? 0;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      print('Error fetching member count: $e');
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  void _refreshDashboard() {
    _fetchMemberCount();
    final auth = context.read<AuthProvider>();
    final todoProv = context.read<TodoProvider>();
    if (auth.user != null) {
      todoProv.syncMyTodos(auth.user!.id);
      if (auth.user!.teamId != null) {
        todoProv.syncTeamTodos(auth.user!.teamId!, auth.user!.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final teamName = auth.user?.teamName ?? 'My Team';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Dashboard', style: AppTextStyles.subHeading),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                teamName, 
                style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
               _refreshDashboard();
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshing Data...')));
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Team Health', style: AppTextStyles.subHeading),
                if (_isLoadingMembers)
                   const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else
                   Text('$_memberCount Members', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final todoProv = context.watch<TodoProvider>();
                
                // --- Local Metrics Calculation (Consolidated) ---
                final allTodos = [...todoProv.myTodos, ...todoProv.teamTodos];
                final totalCount = allTodos.length;
                final processedCount = allTodos.where((t) => t.isCompleted).length;
                final pendingCount = allTodos.where((t) => !t.isCompleted).length;
                
                // Distribution for Chart
                final distribution = <String, int>{};
                for (var t in allTodos) {
                   if (!t.isCompleted) {
                     final p = t.priority.toString();
                     distribution[p] = (distribution[p] ?? 0) + 1;
                   }
                }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;


                      final crossAxisCount = isMobile ? 2 : 4;
                      final childAspectRatio = isMobile ? 1.3 : 1.0; // 2 columns are wide, so 1.3 (W/H) means shorter height? No.
                      // Mobile 2 cols: Width ~170px. Content height ~120px. 170/120 = 1.4. 
                      // So 1.3 is safe. 
                      // Mobile 4 cols: Width ~80px. Content height ~120px. 80/120 = 0.66.
                      // The previous overflowing ratio 1.1 was for 4 columns (implied) or 2?
                      
                      // Let's stick to the plan: 0.85 ratio gives MORE height.
                      // Mobile 2 columns with 0.85 ratio: Width 170, Height 200. That's huge.
                      // Mobile 2 columns with 1.2 ratio: Width 170, Height 141. Good.
                      
                      // Wait, I will use LayoutBuilder again to be safe.
                      // And I will explicitly set 2 columns for mobile.
                      
                      return Column(
                        children: [
                          GridView.count(
                            crossAxisCount: isMobile ? 2 : 4,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            shrinkWrap: true,
                            childAspectRatio: isMobile ? 1.3 : 1.0,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _MetricCard(
                                label: 'Total Tasks', 
                                value: '$totalCount', 
                                icon: Icons.assignment, 
                                color: const Color(0xFF2196F3), // Blue
                                gradientColors: [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
                              ),
                              _MetricCard(
                                label: 'Processed', 
                                value: '$processedCount', 
                                icon: Icons.check_circle_outline, 
                                color: const Color(0xFF4CAF50), // Green
                                gradientColors: [const Color(0xFF43A047), const Color(0xFF81C784)],
                              ),
                              _MetricCard(
                                label: 'Pending', 
                                value: '$pendingCount', 
                                icon: Icons.pending_actions, 
                                color: const Color(0xFFFF9800), // Orange
                                gradientColors: [const Color(0xFFF57C00), const Color(0xFFFFB74D)],
                              ),
                              _MetricCard(
                                label: 'Members', 
                                value: '$_memberCount', 
                                icon: Icons.people, 
                                color: const Color(0xFF9C27B0), // Purple
                                gradientColors: [const Color(0xFF7B1FA2), const Color(0xFFBA68C8)],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Text('Priority Distribution (Active)', style: AppTextStyles.subHeading),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: Row(
                              children: [
                                Expanded(child: _buildPieChart(context, distribution)),
                                const SizedBox(width: 32),
                                _buildLegend(context),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

  Widget _buildPieChart(BuildContext context, Map<dynamic, dynamic> distribution) {
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
  final List<Color>? gradientColors;

  const _MetricCard({
    required this.label, 
    required this.value, 
    required this.icon, 
    required this.color,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: gradientColors != null 
            ? LinearGradient(
                colors: gradientColors!, 
                begin: Alignment.topLeft, 
                end: Alignment.bottomRight
              ) 
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (gradientColors?.first ?? color).withOpacity(0.3), 
            blurRadius: 12, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: gradientColors != null ? Colors.white : color, size: 32),
          const SizedBox(height: 8), // Reduced spacing
          Text(
            value, 
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              color: gradientColors != null ? Colors.white : Colors.black87
            )
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              color: gradientColors != null ? Colors.white.withOpacity(0.9) : Colors.grey, 
              fontWeight: FontWeight.w500
            ), 
            textAlign: TextAlign.center,
            maxLines: 1, // Prevent wrap
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
