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
                if (todo.isSecret)
                  const Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
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
                Checkbox(
                  value: todo.isCompleted,
                  onChanged: (val) {
                    // Update logic
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
