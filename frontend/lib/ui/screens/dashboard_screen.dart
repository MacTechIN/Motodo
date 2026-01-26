import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_card.dart';
import 'admin_dashboard.dart';
import 'completed_box.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        context.read<TodoProvider>().syncMyTodos(auth.user!.id);
        if (auth.user?.teamId != null) {
          context.read<TodoProvider>().syncTeamTodos(auth.user!.teamId!, auth.user!.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final todoProv = context.watch<TodoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Motodo Dashboard', style: AppTextStyles.subHeading),
        actions: [
          if (auth.user?.role == 'admin')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CompletedBox()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                Expanded(child: _buildMyTodos(todoProv)),
                const VerticalDivider(width: 1),
                Expanded(child: _buildTeamTodos(todoProv)),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildMyTodos(todoProv),
                  const Divider(),
                  _buildTeamTodos(todoProv),
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoModal(context),
        backgroundColor: AppColors.priority5,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMyTodos(TodoProvider prov) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Tasks', style: AppTextStyles.subHeading),
          const SizedBox(height: 16),
          ...prov.myTodos.map((todo) => TodoCard(todo: todo)).toList(),
        ],
      ),
    );
  }

  Widget _buildTeamTodos(TodoProvider prov) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Team Collaboration', style: AppTextStyles.subHeading),
          const SizedBox(height: 16),
          ...prov.teamTodos.map((todo) => TodoCard(todo: todo)).toList(),
        ],
      ),
    );
  }

  void _showAddTodoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTodoBottomSheet(),
    );
  }
}

class _AddTodoBottomSheet extends StatefulWidget {
  const _AddTodoBottomSheet();

  @override
  State<_AddTodoBottomSheet> createState() => _AddTodoBottomSheetState();
}

class _AddTodoBottomSheetState extends State<_AddTodoBottomSheet> {
  final _controller = TextEditingController();
  int _priority = 3;
  bool _isSecret = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 32,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add New Task', style: AppTextStyles.subHeading),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'What needs to be done?',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 24),
          const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final p = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _priority = p),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: getPriorityColor(p),
                    shape: BoxShape.circle,
                    border: _priority == p ? Border.all(width: 2) : null,
                  ),
                  child: Center(child: Text('$p')),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Private Task'),
            value: _isSecret,
            onChanged: (val) => setState(() => _isSecret = val),
            secondary: const Icon(Icons.lock),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                final auth = context.read<AuthProvider>();
                context.read<TodoProvider>().addTodo(
                  auth.user!.id,
                  auth.user!.teamId ?? 'default-team',
                  _controller.text,
                  _priority,
                  _isSecret,
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.priority5,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Create Task'),
          ),
        ],
      ),
    );
  }
}
