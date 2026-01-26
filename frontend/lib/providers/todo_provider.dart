import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/todo.dart';

class TodoProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Todo> _myTodos = [];
  List<Todo> _teamTodos = [];

  List<Todo> get myTodos => _myTodos;
  List<Todo> get teamTodos => _teamTodos;

  // Real-time stream for My Todos
  void syncMyTodos(String userId) {
    _db.collection('todos')
       .where('createdBy', isEqualTo: userId)
       .orderBy('priority', descending: true)
       .snapshots()
       .listen((snapshot) {
         _myTodos = snapshot.docs.map((doc) => Todo.fromJson({
           ...doc.data(),
           'id': doc.id,
           'createdAt': (doc.data()['createdAt'] as Timestamp).toDate().toIso8601String(),
         })).toList();
         notifyListeners();
       });
  }

  // Real-time stream for Team Todos (Only Public)
  void syncTeamTodos(String teamId, String currentUserId) {
    _db.collection('todos')
       .where('teamId', isEqualTo: teamId)
       .where('isSecret', isEqualTo: false)
       .snapshots()
       .listen((snapshot) {
         // Filter out our own todos locally if we want separate lists
         _teamTodos = snapshot.docs
             .where((doc) => doc.data()['createdBy'] != currentUserId)
             .map((doc) => Todo.fromJson({
               ...doc.data(),
               'id': doc.id,
               'createdAt': (doc.data()['createdAt'] as Timestamp).toDate().toIso8601String(),
             })).toList();
         notifyListeners();
       });
  }

  Future<bool> addTodo(String userId, String teamId, String content, int priority, bool isSecret, {String? attachmentUrl}) async {
    try {
      final batch = _db.batch();
      
      // 1. Add Todo
      final todoRef = _db.collection('todos').doc();
      batch.set(todoRef, {
        'content': content,
        'priority': priority,
        'isSecret': isSecret,
        'isCompleted': false,
        'createdBy': userId,
        'teamId': teamId,
        'attachmentUrl': attachmentUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Increment Sharded Counter (e.g. 5 shards)
      final shardId = (DateTime.now().millisecond % 5).toString();
      final shardRef = _db.collection('teams').doc(teamId).collection('counters').doc(shardId);
      batch.set(shardRef, {
        'total': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await batch.commit();
      return true;
    } catch (e) {
      print('Add todo error: $e');
      return false;
    }
  }

  Future<void> toggleComplete(String todoId, String teamId, bool isCompleted) async {
    final batch = _db.batch();
    
    // 1. Update Todo
    batch.update(_db.collection('todos').doc(todoId), {
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });

    // 2. Update Sharded Counter
    final shardId = (DateTime.now().millisecond % 5).toString();
    final shardRef = _db.collection('teams').doc(teamId).collection('counters').doc(shardId);
    batch.set(shardRef, {
      'completed': FieldValue.increment(isCompleted ? 1 : -1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // --- Comments Sub-collection Logic ---

  Stream<List<Map<String, dynamic>>> syncComments(String todoId) {
    return _db.collection('todos').doc(todoId).collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> addComment(String todoId, String userId, String userName, String content) async {
    await _db.collection('todos').doc(todoId).collection('comments').add({
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
