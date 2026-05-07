class Delivery {
  final int id;
  final int stationId;
  final int tankId;
  final String productType;
  final double quantity;
  final double? actualReceivedVolume;
  final double unitPrice;
  final double totalAmount;
  final String supplierName;
  final String? deliveryNoteNumber;
  final DateTime deliveredAt;
  final String? notes;
  final DateTime createdAt;

  const Delivery({
    required this.id,
    required this.stationId,
    required this.tankId,
    required this.productType,
    required this.quantity,
    this.actualReceivedVolume,
    required this.unitPrice,
    required this.totalAmount,
    required this.supplierName,
    this.deliveryNoteNumber,
    required this.deliveredAt,
    this.notes,
    required this.createdAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'] as int,
      stationId: json['stationId'] as int,
      tankId: json['tankId'] as int,
      productType: json['productType'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      actualReceivedVolume: json['actualReceivedVolume'] != null
          ? (json['actualReceivedVolume'] as num).toDouble()
          : null,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      supplierName: json['supplierName'] as String,
      deliveryNoteNumber: json['deliveryNoteNumber'] as String?,
      deliveredAt: DateTime.parse(json['deliveredAt'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
