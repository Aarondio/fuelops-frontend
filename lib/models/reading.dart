class Reading {
  final int id;
  final int? stationId;
  final int pumpId;
  final String? pumpName;
  final int? attendantId;
  final String? attendantName;
  final double openingReading;
  final double? closingReading;
  final double? volumeSold;
  final double? declaredLitresSold;
  final double? declaredCashCollected;
  final double? priceAtClose;
  final double? expectedRevenue;
  final double? volumeVariance;
  final double? revenueVariance;
  final String? varianceStatus;
  final String status;
  final DateTime? closedAt;
  final int? handoverConfirmedBy;
  final DateTime? handoverConfirmedAt;
  final DateTime date;
  final String shift;
  final String? notes;
  final double? ocrConfidence;
  final bool lowConfidenceFlag;
  final DateTime createdAt;

  const Reading({
    required this.id,
    this.stationId,
    required this.pumpId,
    this.pumpName,
    this.attendantId,
    this.attendantName,
    required this.openingReading,
    this.closingReading,
    this.volumeSold,
    this.declaredLitresSold,
    this.declaredCashCollected,
    this.priceAtClose,
    this.expectedRevenue,
    this.volumeVariance,
    this.revenueVariance,
    this.varianceStatus,
    required this.status,
    this.closedAt,
    this.handoverConfirmedBy,
    this.handoverConfirmedAt,
    required this.date,
    required this.shift,
    this.notes,
    this.ocrConfidence,
    this.lowConfidenceFlag = false,
    required this.createdAt,
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get needsHandover => isClosed && handoverConfirmedAt == null;

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] as int,
      stationId: json['stationId'] as int?,
      pumpId: json['pumpId'] as int,
      pumpName: (json['pump'] as Map<String, dynamic>?)?['name'] as String?,
      attendantId: json['attendantId'] as int?,
      attendantName: (json['attendant'] as Map<String, dynamic>?)?['name'] as String?,
      openingReading: (json['openingReading'] as num).toDouble(),
      closingReading: json['closingReading'] != null
          ? (json['closingReading'] as num).toDouble()
          : null,
      volumeSold: json['volumeSold'] != null
          ? (json['volumeSold'] as num).toDouble()
          : null,
      declaredLitresSold: json['declaredLitresSold'] != null
          ? (json['declaredLitresSold'] as num).toDouble()
          : null,
      declaredCashCollected: json['declaredCashCollected'] != null
          ? (json['declaredCashCollected'] as num).toDouble()
          : null,
      priceAtClose: json['priceAtClose'] != null
          ? (json['priceAtClose'] as num).toDouble()
          : null,
      expectedRevenue: json['expectedRevenue'] != null
          ? (json['expectedRevenue'] as num).toDouble()
          : null,
      volumeVariance: json['volumeVariance'] != null
          ? (json['volumeVariance'] as num).toDouble()
          : null,
      revenueVariance: json['revenueVariance'] != null
          ? (json['revenueVariance'] as num).toDouble()
          : null,
      varianceStatus: json['varianceStatus'] as String?,
      status: json['status'] as String? ?? 'closed',
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'] as String)
          : null,
      handoverConfirmedBy: json['handoverConfirmedBy'] as int?,
      handoverConfirmedAt: json['handoverConfirmedAt'] != null
          ? DateTime.parse(json['handoverConfirmedAt'] as String)
          : null,
      date: DateTime.parse(json['date'] as String),
      shift: json['shift'] as String,
      notes: json['notes'] as String?,
      ocrConfidence: json['ocrConfidence'] != null
          ? (json['ocrConfidence'] as num).toDouble()
          : null,
      lowConfidenceFlag: json['lowConfidenceFlag'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
