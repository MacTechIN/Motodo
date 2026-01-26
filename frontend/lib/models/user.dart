class User {
  final String id;
  final String email;
  final String displayName;
  final String? teamId;
  final String role;
  final String? statusMessage;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.teamId,
    required this.role,
    this.statusMessage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      displayName: json['displayName'],
      teamId: json['teamId'],
      role: json['role'] ?? 'member',
      statusMessage: json['statusMessage'],
    );
  }
}
