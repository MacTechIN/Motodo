import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:frontend/providers/todo_provider.dart';
import 'package:frontend/models/todo.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late TodoProvider todoProvider;

  // Constants
  const myUserId = 'testuser99';
  const otherUserId = 'other';
  const teamId = 'OmegaTeam';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    todoProvider = TodoProvider(firestore: fakeFirestore);
  });

  test('Verify Team Health Aggregation Metrics', () async {
    // 1. Seed Data
    // My Task: P2 (Public)
    await fakeFirestore.collection('todos').add({
      'content': 'My P2 Task',
      'priority': 2,
      'isSecret': false,
      'isCompleted': false,
      'createdBy': myUserId,
      'teamId': teamId,
      'createdAt': DateTime.now().toIso8601String(), // timestamps in fakeFS can be strings or Timestamp objects
    });

    // Other Task: P1 (Public) - Urgent
    await fakeFirestore.collection('todos').add({
      'content': 'Other P1 Task',
      'priority': 1,
      'isSecret': false,
      'isCompleted': false,
      'createdBy': otherUserId,
      'teamId': teamId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Other Task: P3 (Public) - Normal
    await fakeFirestore.collection('todos').add({
      'content': 'Other P3 Task',
      'priority': 3,
      'isSecret': false,
      'isCompleted': false,
      'createdBy': otherUserId,
      'teamId': teamId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Other Task: P1 (Private) - Should be HIDDEN from Team Health
    await fakeFirestore.collection('todos').add({
      'content': 'Other Private P1 Task',
      'priority': 1,
      'isSecret': true,
      'isCompleted': false,
      'createdBy': otherUserId,
      'teamId': teamId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // 2. Trigger Sync
    todoProvider.syncMyTodos(myUserId);
    todoProvider.syncTeamTodos(teamId, myUserId);

    // Wait for streams (FakeFirestore is usually immediate, but streams are async)
    await Future.delayed(Duration(milliseconds: 100));

    // 3. Aggregate Data (Mimicking AdminDashboard logic)
    final allTodos = [...todoProvider.myTodos, ...todoProvider.teamTodos];

    // 4. Print for Debugging
    print('My Todos: ${todoProvider.myTodos.length}');
    print('Team Todos: ${todoProvider.teamTodos.length}');
    for (var t in allTodos) {
      print('Task: ${t.content}, P: ${t.priority}, Secret: ${t.isSecret}, Creator: ${t.createdBy}');
    }

    // 5. Assertions

    // Total Count should be 3 (My P2 + Other P1 + Other P3)
    // Other Private P1 should be excluded by syncTeamTodos query + filter
    expect(allTodos.length, 3, reason: 'Total tasks should be 3 (1 Mine + 2 Other Public)');

    // Urgent (P1) Count
    // Should be 1 (Other P1 Public). My P2 is not urgent. Other Private P1 is hidden.
    final urgentP1Count = allTodos.where((t) => t.priority == 1 && !t.isCompleted).length;
    expect(urgentP1Count, 1, reason: 'Should have exactly 1 Urgent (P1) task');

    // Priority Distribution
    final distribution = <String, int>{};
    for (var t in allTodos) {
      if (!t.isCompleted) {
        final p = t.priority.toString();
        distribution[p] = (distribution[p] ?? 0) + 1;
      }
    }

    expect(distribution['1'], 1, reason: 'P1 count should be 1');
    expect(distribution['2'], 1, reason: 'P2 count should be 1');
    expect(distribution['3'], 1, reason: 'P3 count should be 1');
    expect(distribution.containsKey('4'), false);
    expect(distribution.containsKey('5'), false);

  });
}
