import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../providers/auth_provider.dart';

class PulseView extends StatelessWidget {
  const PulseView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final teamId = auth.user?.teamId ?? 'default-team';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Pulse', style: AppTextStyles.subHeading),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(teamId)
            .collection('members')
            .orderBy('activeCount', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final members = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length + 1, // +1 for Header
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader();
              }
              final doc = members[index - 1];
              final data = doc.data() as Map<String, dynamic>;
              return _MemberPulseCard(userId: doc.id, stats: data);
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        'Real-time Workload Monitor',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}

class _MemberPulseCard extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> stats;

  const _MemberPulseCard({required this.userId, required this.stats});

  @override
  Widget build(BuildContext context) {
    final active = stats['activeCount'] ?? 0;
    final secret = stats['secretCount'] ?? 0;
    final urgent = stats['highPriorityCount'] ?? 0;
    final lastActive = (stats['lastActivityAt'] as Timestamp?)?.toDate();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final name = userData?['displayName'] ?? 'Unknown User';
        final email = userData?['email'] ?? userId;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withOpacity(0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(child: Text(name[0])),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (lastActive != null)
                        Text(
                          'Last Active: ${_formatTime(lastActive)}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                _StatBadge(label: 'Active', value: active.toString(), color: Colors.blue),
                const SizedBox(width: 8),
                _StatBadge(label: 'Urgent', value: urgent.toString(), color: Colors.red),
                const SizedBox(width: 8),
                if (secret > 0)
                  _StatBadge(label: 'Private', value: secret.toString(), color: Colors.grey, icon: Icons.lock),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  const _StatBadge({required this.label, required this.value, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
