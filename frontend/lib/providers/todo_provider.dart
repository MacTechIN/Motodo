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

  Future<bool> addTodo(String userId, String teamId, String content, int priority, bool isSecret) async {
    try {
      await _db.collection('todos').add({
        'content': content,
        'priority': priority,
        'isSecret': isSecret,
        'isCompleted': false,
        'createdBy': userId,
        'teamId': teamId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Add todo error: $e');
      return false;
    }
  }

  Future<void> toggleComplete(String todoId, bool isCompleted) async {
    await _db.collection('todos').doc(todoId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }
}
