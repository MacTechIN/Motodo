import 'package:flutter/material.dart';
import '../../core/design_system.dart';
import '../../models/todo.dart';

class TodoCard extends StatelessWidget {
  final Todo todo;

  const TodoCard({super.key, required this.todo});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: getPriorityColor(todo.priority),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    todo.content,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (todo.attachmentUrl != null)
                  const Icon(Icons.attach_file, size: 16, color: AppColors.textSecondary),
                if (todo.isSecret)
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Priority ${todo.priority}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.comment_outlined, size: 20),
                  onPressed: () => _showComments(context),
                  color: AppColors.textSecondary,
                ),
                Checkbox(
                  value: todo.isCompleted,
                  onChanged: (val) {
                    if (val != null) {
                      context.read<TodoProvider>().toggleComplete(todo.id, todo.teamId, val);
                    }
                  },
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
