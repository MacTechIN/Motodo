import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_card.dart';

class CompletedBox extends StatelessWidget {
  const CompletedBox({super.key});

  @override
  Widget build(BuildContext context) {
    final completedTodos = context.watch<TodoProvider>().myTodos.where((t) => t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('History (Completed)', style: AppTextStyles.subHeading)),
      body: completedTodos.isEmpty
          ? const Center(child: Text('No completed tasks yet.', style: AppTextStyles.body))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: completedTodos.length,
              itemBuilder: (context, index) => TodoCard(todo: completedTodos[index]),
            ),
    );
  }
}
