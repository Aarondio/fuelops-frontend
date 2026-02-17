class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? stationId;
  final String? stationName;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.stationId,
    this.stationName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      stationId: json['stationId'] as int?,
      stationName: json['station']?['name'] as String?,
    );
  }
}
