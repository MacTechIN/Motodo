import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/todo.dart';

class TodoProvider with ChangeNotifier {
  List<Todo> _myTodos = [];
  List<Todo> _teamTodos = [];
  final String _baseUrl = 'http://localhost:3000';

  List<Todo> get myTodos => _myTodos;
  List<Todo> get teamTodos => _teamTodos;

  Future<void> fetchTodos(String token) async {
    try {
      final myResponse = await http.get(
        Uri.parse('$_baseUrl/todos/my'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final teamResponse = await http.get(
        Uri.parse('$_baseUrl/todos/team'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (myResponse.statusCode == 200) {
        final List data = json.decode(myResponse.body);
        _myTodos = data.map((json) => Todo.fromJson(json)).toList();
      }

      if (teamResponse.statusCode == 200) {
        final List data = json.decode(teamResponse.body);
        _teamTodos = data.map((json) => Todo.fromJson(json)).toList();
      }

      notifyListeners();
    } catch (e) {
      print('Fetch todos error: $e');
    }
  }

  Future<bool> addTodo(String token, String content, int priority, bool isSecret) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/todos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'content': content,
          'priority': priority,
          'isSecret': isSecret,
        }),
      );

      if (response.statusCode == 201) {
        await fetchTodos(token);
        return true;
      }
      return false;
    } catch (e) {
      print('Add todo error: $e');
      return false;
    }
  }
}
