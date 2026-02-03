import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'dart:convert';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Users (Debug)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final uid = doc.id;
              final email = data['email'] ?? 'No Email';
              final displayName = data['displayName'] ?? 'No Name';
              final teamId = data['teamId'];
              final role = data['role'] ?? 'N/A';
              final createdAt = data['createdAt'] as Timestamp?;

              return ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: teamId != null ? Colors.green.shade100 : Colors.red.shade100,
                  child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
                ),
                title: Text(displayName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email),
                    Text('UID: $uid', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                trailing: Chip(
                  label: Text(role),
                  backgroundColor: role == 'admin' ? Colors.orange.shade100 : Colors.grey.shade100,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Team ID', teamId ?? 'NULL (Issue: Not Assigned)'),
                        _buildInfoRow('Team Name', data['teamName'] ?? 'No Team Name'),
                        _buildInfoRow('Created', createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate()) : 'Unknown'),
                        const Divider(),
                        
                        // Action Buttons
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text("Manually Assign Team"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              onPressed: () {
                                _showEditTeamDialog(context, displayName, uid);
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        const Text("Raw Data:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: SelectableText(
                            _formatData(data),
                            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEditTeamDialog(BuildContext context, String userName, String targetUid) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('teams').snapshots(),
          builder: (context, teamSnapshot) {
            final existingTeams = teamSnapshot.data?.docs
                .map((d) => (d.data() as Map<String, dynamic>)['name'] as String? ?? '')
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList() ?? [];

            return AlertDialog(
              title: Text("Assign Team for $userName"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select an existing team or type a new one:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return existingTeams;
                      }
                      return existingTeams.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      controller.text = selection;
                    },
                    fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                      // Sync with our outer controller if needed, but easier to just use fieldController
                      if (controller.text.isNotEmpty && fieldController.text.isEmpty) {
                         fieldController.text = controller.text;
                      }
                      return TextField(
                        controller: fieldController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: "Team Name",
                          hintText: "Selection or New Name",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => controller.text = val,
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    // Check either controller or fieldController (Autocomplete can be tricky)
                    final tName = controller.text.trim();
                    if (tName.isNotEmpty) {
                      Navigator.pop(context);
                      _assignTeamToUser(context, targetUid, tName);
                    }
                  },
                  child: const Text("Assign"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignTeamToUser(BuildContext context, String targetUid, String teamNameInput) async {
     try {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing...")));
       
       final teamName = teamNameInput.trim();
       String teamId = '';
       
       // 1. Find or Create Team
       final teamQuery = await FirebaseFirestore.instance
          .collection('teams')
          .where('name', isEqualTo: teamName)
          .limit(1)
          .get();

       if (teamQuery.docs.isNotEmpty) {
          teamId = teamQuery.docs.first.id;
       } else {
          // Create new team
          final teamRef = FirebaseFirestore.instance.collection('teams').doc();
          await teamRef.set({
            'name': teamName,
            'adminUid': targetUid, // Assign this user as admin since they are first? Or keep generic.
            'createdAt': FieldValue.serverTimestamp(),
            'plan': 'free', 
            'stats': {'totalCount': 0, 'totalCompleted': 0}
          });
          teamId = teamRef.id;
       }

       // 2. Update Target User
       await FirebaseFirestore.instance.collection('users').doc(targetUid).set({
          'teamId': teamId,
          'teamName': teamName,
          'role': 'member' // Default to member or keep existing? Safe merge will handle.
       }, SetOptions(merge: true));

       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Success: Assigned $teamName to user"), backgroundColor: Colors.green));
     } catch (e) {
       print(e);
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
     }
  }
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  /// Formats the raw data Map into a sorted, indented JSON string for consistency.
  String _formatData(Map<String, dynamic> data) {
    // Sort keys alphabetically
    final sortedKeys = data.keys.toList()..sort();
    final sortedMap = Map.fromEntries(sortedKeys.map((k) => MapEntry(k, data[k])));
    
    // Format as Pretty JSON, handling non-encodable objects like Timestamp
    final encoder = JsonEncoder.withIndent('  ', (val) {
      if (val is Timestamp) {
        return val.toDate().toIso8601String();
      }
      return val;
    });
    
    try {
      return encoder.convert(sortedMap);
    } catch (e) {
      return "Error formatting data: $e\nRaw: $sortedMap";
    }
  }
}
