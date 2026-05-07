import 'wholesale_customer.dart';

class WholesaleTransaction {
  final int id;
  final int stationId;
  final int wholesaleCustomerId;
  final String productType;
  final double quantity;
  final double unitPrice;
  final double totalAmount;
  final String paymentStatus; // paid | credit | partial
  final double amountPaid;
  final String? referenceNumber;
  final DateTime transactionDate;
  final String? notes;
  final WholesaleCustomer? customer;
  final DateTime createdAt;

  const WholesaleTransaction({
    required this.id,
    required this.stationId,
    required this.wholesaleCustomerId,
    required this.productType,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.paymentStatus,
    required this.amountPaid,
    this.referenceNumber,
    required this.transactionDate,
    this.notes,
    this.customer,
    required this.createdAt,
  });

  double get outstanding => totalAmount - amountPaid;
  bool get isPaid => paymentStatus == 'paid';
  bool get isCredit => paymentStatus == 'credit';
  bool get isPartial => paymentStatus == 'partial';

  factory WholesaleTransaction.fromJson(Map<String, dynamic> json) {
    WholesaleCustomer? customer;
    if (json['customer'] != null && json['customer'] is Map<String, dynamic>) {
      customer = WholesaleCustomer.fromJson(json['customer'] as Map<String, dynamic>);
    }
    return WholesaleTransaction(
      id: json['id'] as int,
      stationId: json['stationId'] as int,
      wholesaleCustomerId: json['wholesaleCustomerId'] as int,
      productType: json['productType'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      paymentStatus: json['paymentStatus'] as String,
      amountPaid: (json['amountPaid'] as num).toDouble(),
      referenceNumber: json['referenceNumber'] as String?,
      transactionDate: DateTime.tryParse(json['transactionDate'] as String? ?? '') ?? DateTime.now(),
      notes: json['notes'] as String?,
      customer: customer,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
