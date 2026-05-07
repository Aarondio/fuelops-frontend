class AppNotification {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  String get title {
    return (data['title'] as String?) ??
        (data['type'] as String?)?.replaceAll('_', ' ').toUpperCase() ??
        type.replaceAll('Notification', '').toUpperCase();
  }

  String get body {
    return (data['message'] as String?) ??
        (data['body'] as String?) ??
        '';
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
