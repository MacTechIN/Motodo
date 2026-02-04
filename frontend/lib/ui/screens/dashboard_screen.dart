import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_card.dart';
import '../admin/admin_layout.dart';
import 'completed_box.dart';
import '../../models/todo.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AuthProvider? _authProvider;
  String? _lastUserId;
  String? _lastTeamId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider = context.read<AuthProvider>();
      _authProvider?.addListener(_onAuthUpdated);
      _onAuthUpdated(); // Initial check
    });
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthUpdated);
    super.dispose();
  }

  void _onAuthUpdated() {
    if (!mounted || _authProvider == null) return;
    final user = _authProvider!.user;
    
    if (user != null) {
      if (user.id != _lastUserId) {
        _lastUserId = user.id;
        context.read<TodoProvider>().syncMyTodos(user.id);
      }
      
      if (user.teamId != _lastTeamId) {
        _lastTeamId = user.teamId;
        if (user.teamId != null) {
          context.read<TodoProvider>().syncTeamTodos(user.teamId!, user.id);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final todoProv = context.watch<TodoProvider>();

    return Scaffold(
      backgroundColor: Colors.white, // Match the clean white background
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          
          if (isDesktop) {
            // Desktop Layout: Two columns
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomHeader(auth, context),
                    const SizedBox(height: 32),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: My Focus
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('My Focus', style: AppTextStyles.subHeading),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ListView(
                                    children: todoProv.myTodos
                                        .where((t) => !t.isCompleted)
                                        .map((todo) => TodoCard(todo: todo))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Right Column: Team's Progress
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Team's Progress", style: AppTextStyles.subHeading),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: _buildTeamProgressGrid(todoProv, isDesktop: true), // Pass isDesktop
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Mobile/Tablet Layout: Single Column
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     const SizedBox(height: 20),
                    _buildCustomHeader(auth, context),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('My Focus', style: AppTextStyles.subHeading),
                            const SizedBox(height: 16),
                            ...todoProv.myTodos
                                .where((t) => !t.isCompleted)
                                .map((todo) => TodoCard(todo: todo))
                                .toList(),
                            
                            const SizedBox(height: 32),
                            const Text("Team's Progress", style: AppTextStyles.subHeading),
                            const SizedBox(height: 16),
                            _buildTeamProgressGrid(todoProv, isDesktop: false),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoModal(context),
        backgroundColor: const Color(0xFFBAFFC9),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.black87, size: 28),
      ),
      // On desktop, FAB might look better bottom right, but center float is fine for now
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, 
    );
  }

  Widget _buildCustomHeader(AuthProvider auth, BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(now);
    final hour = now.hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    final displayName = auth.user?.displayName;
    final nameToDisplay = (displayName != null && displayName.isNotEmpty) ? displayName.split(' ').first : 'Member';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, $nameToDisplay!',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        // User Profile Icon (Navigates to Settings or just visual)
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            radius: 24,
            child: Text(
              nameToDisplay.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamProgressGrid(TodoProvider prov, {required bool isDesktop}) {
    if (prov.teamTodos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              "No team activity yet",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            SizedBox(height: 4),
            Text(
              "Tasks shared by your team will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
      );
    }
    
    // Show recent tasks
    final recentTeamTodos = prov.teamTodos.take(6).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTeamTodos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 1 : 2, // 1 column on desktop sidebar, 2 on mobile grid
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isDesktop ? 2.5 : 1.4, // Adjust aspect ratio for desktop list styling vs mobile card
      ),
      itemBuilder: (context, index) {
        return _TeamTaskItem(todo: recentTeamTodos[index]);
      },
    );
  }


  Widget _buildHeader(TodoProvider prov, BuildContext context) {
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
              Row(
                children: [
                   IconButton(
                    icon: const Icon(Icons.history, color: Colors.grey),
                    tooltip: 'View Completed Tasks',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CompletedBox()),
                      );
                    },
                  ),
                  Text('${(progress * 100).toInt()}% Done', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.priority5)),
                ],
              ),
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
          _buildHeader(prov, context),
          const SizedBox(height: 16),
          // Sort by priority descending (5 -> 1)
          ...prov.myTodos.map((todo) => TodoCard(todo: todo)).toList(),
        ],
      ),
    );
  }

  Widget _buildTeamTodos(TodoProvider prov) {
    final auth = context.read<AuthProvider>();
    final teamName = auth.user?.teamName ?? 'Team';
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$teamName\'s Progress', style: AppTextStyles.subHeading),
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

class _TeamTaskItem extends StatelessWidget {
  final Todo todo;
  const _TeamTaskItem({required this.todo});

  @override
  Widget build(BuildContext context) {
    // Calculate "Time Ago" roughly
    final createdAt = DateTime.tryParse(todo.createdAt?.toString() ?? '') ?? DateTime.now();
    final diff = DateTime.now().difference(createdAt);
    String timeAgo = '${diff.inMinutes}m ago';
    if (diff.inHours > 0) timeAgo = '${diff.inHours}h ago';
    if (diff.inDays > 0) timeAgo = '${diff.inDays}d ago';

    final customColors = context.select<AuthProvider, Map<int, Color>?>((p) => p.customColors);
    final color = getPriorityColor(todo.priority, customColors);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color, 
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                'Priority ${todo.priority}:', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
              ),
              const SizedBox(height: 4),
              Text(
                todo.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(timeAgo, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              if (todo.isSecret) const Icon(Icons.lock, size: 12, color: Colors.black54),
            ],
          ),
        ],
      ),
    );
  }
}
