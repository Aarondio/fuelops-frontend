class Reading {
  final int id;
  final int pumpId;
  final String? pumpName;
  final double openingReading;
  final double? closingReading;
  final double? volumeSold;
  final String status; // 'open' or 'closed'
  final DateTime date;
  final String shift;
  final String? notes;
  final DateTime createdAt;

  Reading({
    required this.id,
    required this.pumpId,
    this.pumpName,
    required this.openingReading,
    this.closingReading,
    this.volumeSold,
    required this.status,
    required this.date,
    required this.shift,
    this.notes,
    required this.createdAt,
  });

  bool get isOpen => status == 'open';

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] as int,
      pumpId: json['pumpId'] as int,
      pumpName: json['pump']?['name'] as String?,
      openingReading: (json['openingReading'] as num).toDouble(),
      closingReading: json['closingReading'] != null
          ? (json['closingReading'] as num).toDouble()
          : null,
      volumeSold: json['volumeSold'] != null
          ? (json['volumeSold'] as num).toDouble()
          : null,
      status: json['status'] as String? ?? 'closed',
      date: DateTime.parse(json['date'] as String),
      shift: json['shift'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
