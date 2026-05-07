class Tank {
  final int id;
  final int stationId;
  final String productType;
  final double capacity;
  final double currentLevel;

  const Tank({
    required this.id,
    required this.stationId,
    required this.productType,
    required this.capacity,
    required this.currentLevel,
  });

  double get fillPercentage => capacity > 0 ? (currentLevel / capacity * 100).clamp(0, 100) : 0;

  String get displayName => '$productType Tank #$id';

  factory Tank.fromJson(Map<String, dynamic> json) {
    return Tank(
      id: json['id'] as int,
      stationId: json['stationId'] as int,
      productType: json['productType'] as String,
      capacity: (json['capacity'] as num).toDouble(),
      currentLevel: (json['currentLevel'] as num).toDouble(),
    );
  }
}
