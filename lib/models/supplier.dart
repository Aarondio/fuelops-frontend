class Supplier {
  final int id;
  final int stationId;
  final String name;
  final String? phone;
  final String? address;
  final DateTime createdAt;

  const Supplier({
    required this.id,
    required this.stationId,
    required this.name,
    this.phone,
    this.address,
    required this.createdAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as int,
      stationId: json['stationId'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'station_id': stationId,
        'name': name,
        'phone': phone,
        'address': address,
        'created_at': createdAt.toIso8601String(),
      };

  factory Supplier.fromRow(Map<String, dynamic> row) {
    return Supplier(
      id: row['id'] as int,
      stationId: row['station_id'] as int,
      name: row['name'] as String,
      phone: row['phone'] as String?,
      address: row['address'] as String?,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
