class TankDip {
  final int id;
  final int tankId;
  final int stationId;
  final int recordedBy;
  final String date;
  final double openingDip;
  final double? closingDip;
  final double deliveriesReceived;
  final double volumeDispensed;
  final double? expectedClosing;
  final double? variance;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const TankDip({
    required this.id,
    required this.tankId,
    required this.stationId,
    required this.recordedBy,
    required this.date,
    required this.openingDip,
    this.closingDip,
    required this.deliveriesReceived,
    required this.volumeDispensed,
    this.expectedClosing,
    this.variance,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';

  factory TankDip.fromJson(Map<String, dynamic> json) {
    return TankDip(
      id: json['id'] as int,
      tankId: json['tankId'] as int,
      stationId: json['stationId'] as int,
      recordedBy: json['recordedBy'] as int,
      date: json['date'] as String,
      openingDip: (json['openingDip'] as num).toDouble(),
      closingDip: json['closingDip'] != null
          ? (json['closingDip'] as num).toDouble()
          : null,
      deliveriesReceived: (json['deliveriesReceived'] as num).toDouble(),
      volumeDispensed: (json['volumeDispensed'] as num).toDouble(),
      expectedClosing: json['expectedClosing'] != null
          ? (json['expectedClosing'] as num).toDouble()
          : null,
      variance: json['variance'] != null
          ? (json['variance'] as num).toDouble()
          : null,
      status: json['status'] as String? ?? 'open',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
