class Attendant {
  final int id;
  final int stationId;
  final String name;
  final String? phone;
  final bool isActive;

  const Attendant({
    required this.id,
    required this.stationId,
    required this.name,
    this.phone,
    this.isActive = true,
  });

  factory Attendant.fromJson(Map<String, dynamic> json) {
    return Attendant(
      id: json['id'] as int,
      stationId: json['stationId'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
