import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../models/todo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';

class TodoCard extends StatelessWidget {
  final Todo todo;

  const TodoCard({super.key, required this.todo});

  @override
  Widget build(BuildContext context) {
    final customColors = context.select<AuthProvider, Map<int, Color>?>((p) => p.customColors);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16), // Increased margin
      color: getPriorityColor(todo.priority, customColors),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // More rounded
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Content & Icons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    todo.content,
                    style: TextStyle(
                      fontSize: 18, // Larger font
                      fontWeight: FontWeight.w600,
                      decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (todo.attachmentUrl != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.attach_file, size: 20, color: Colors.black54),
                  ),
                if (todo.isSecret)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.lock_outline, size: 20, color: Colors.black54),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Bottom Row: Checkbox & Meta
            Row(
              children: [
               // Checkbox with custom style to match image (approx)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (val) {
                      if (val != null) {
                        context.read<TodoProvider>().toggleComplete(todo.id, todo.teamId, val);
                      }
                    },
                    activeColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  todo.isCompleted ? 'Done' : 'Mark as Done',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const Spacer(),
                const Icon(Icons.outlined_flag, size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Text(
                  'Priority: ${todo.priority}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentDialog(todoId: todo.id),
    );
  }
}

class _CommentDialog extends StatefulWidget {
  final String todoId;
  const _CommentDialog({required this.todoId});

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Comments', style: AppTextStyles.subHeading),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context.read<TodoProvider>().syncComments(widget.todoId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final comments = snapshot.data!;
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final c = comments[index];
                    return ListTile(
                      title: Text(c['userName'] ?? 'User', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text(c['content'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: 'Add a comment...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_commentController.text.isNotEmpty) {
                      context.read<TodoProvider>().addComment(
                        widget.todoId,
                        auth.user!.id,
                        auth.user!.displayName,
                        _commentController.text,
                      );
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
