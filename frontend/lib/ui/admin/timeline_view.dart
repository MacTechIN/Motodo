import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../providers/auth_provider.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final teamId = auth.user?.teamId ?? 'default-team';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Activity', style: AppTextStyles.subHeading),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to completed tasks in real-time
        stream: FirebaseFirestore.instance
            .collection('todos')
            .where('teamId', isEqualTo: teamId)
            .where('isCompleted', isEqualTo: true)
            .where('isSecret', isEqualTo: false) // Don't show secret tasks in public timeline
            .orderBy('completedAt', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No recent activity."));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _TimelineItem(data: data);
            },
          );
        },
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TimelineItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
    final content = data['content'] ?? '';
    final userId = data['createdBy'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 50),
                   child: Text(
                    completedAt != null ? "${completedAt.hour}:${completedAt.minute.toString().padLeft(2, '0')}" : "",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                const Icon(Icons.check_circle, color: AppColors.priority4, size: 20),
                Expanded(child: Container(width: 2, color: Colors.grey.withOpacity(0.2))),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, snapshot) {
                  final userName = snapshot.data?.get('displayName') ?? 'Someone';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black, fontSize: 14),
                            children: [
                              TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: " completed task"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          content, 
                          maxLines: 2, 
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
