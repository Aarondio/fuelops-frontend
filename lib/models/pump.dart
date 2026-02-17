class Pump {
  final int id;
  final int stationId;
  final String name;
  final String productType;
  final double currentPrice;
  final List<Dispenser> dispensers;

  Pump({
    required this.id,
    required this.stationId,
    required this.name,
    required this.productType,
    required this.currentPrice,
    this.dispensers = const [],
  });

  factory Pump.fromJson(Map<String, dynamic> json) {
    return Pump(
      id: json['id'] as int,
      stationId: json['stationId'] as int,
      name: json['name'] as String,
      productType: json['productType'] as String? ?? 'PMS',
      currentPrice: (json['currentPrice'] as num).toDouble(),
      dispensers: json['dispensers'] != null
          ? (json['dispensers'] as List)
              .map((d) => Dispenser.fromJson(d as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Pump && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Dispenser {
  final int id;
  final String name;

  Dispenser({required this.id, required this.name});

  factory Dispenser.fromJson(Map<String, dynamic> json) {
    return Dispenser(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
