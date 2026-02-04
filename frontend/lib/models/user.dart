class User {
  final String id;
  final String email;
  final String displayName;
  final String? teamId;
  final String? teamName;
  final String role;
  final String? statusMessage;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.teamId,
    this.teamName,
    required this.role,
    this.statusMessage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      displayName: json['displayName'],
      teamId: json['teamId'],
      teamName: json['teamName'],
      role: json['role'] ?? 'member',
      statusMessage: json['statusMessage'],
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? teamId,
    String? teamName,
    String? role,
    String? statusMessage,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      role: role ?? this.role,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}
