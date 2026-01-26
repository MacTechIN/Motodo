import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_card.dart';
import '../widgets/todo_card.dart';
import '../admin/admin_layout.dart';
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
                MaterialPageRoute(builder: (context) => const AdminLayout()),
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
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    children: [
                      Expanded(child: SingleChildScrollView(child: _buildMyTodos(todoProv))),
                      const VerticalDivider(width: 1),
                      Expanded(child: SingleChildScrollView(child: _buildTeamTodos(todoProv))),
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
          ),
          _buildTeamTicker(todoProv),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoModal(context),
        backgroundColor: AppColors.priority5,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(TodoProvider prov) {
    // Progress Bar Calculation
    final total = prov.myTodos.length;
    final completed = prov.myTodos.where((t) => t.isCompleted).length;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Focus', style: AppTextStyles.heading),
              Text('${(progress * 100).toInt()}% Done', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.priority5)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            color: AppColors.priority5,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTicker(TodoProvider prov) {
    // Show last 3 completed team tasks
    final completedTeamTodos = prov.teamTodos
        .where((t) => t.isCompleted)
        .take(3)
        .toList();

    if (completedTeamTodos.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.priority1,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          const Text('Team Activity: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(
            child: SizedBox(
               height: 20,
               child: ListView.builder(
                 scrollDirection: Axis.horizontal,
                 itemCount: completedTeamTodos.length,
                 itemBuilder: (context, index) {
                   return Padding(
                     padding: const EdgeInsets.only(right: 16.0),
                     child: Text(
                       '${completedTeamTodos[index].content} done',
                       style: const TextStyle(fontSize: 12),
                     ),
                   );
                 },
               ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTodos(TodoProvider prov) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(prov),
          const SizedBox(height: 16),
          // Sort by priority descending (5 -> 1)
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
          Expanded( // Make scrollable separately if needed, or just list
             child: Column(
               children: prov.teamTodos.map((todo) => TodoCard(todo: todo)).toList(),
             ),
          ),
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
  final _attachmentController = TextEditingController();
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
          const SizedBox(height: 16),
          const Text('Attachment URL', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _attachmentController,
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false, // Simulated: Disabled for free users
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PREMIUM',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
                  attachmentUrl: _attachmentController.text.isNotEmpty ? _attachmentController.text : null,
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
