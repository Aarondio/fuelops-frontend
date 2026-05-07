class WholesaleCustomer {
  final int id;
  final int stationId;
  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? address;
  final double creditLimit;
  final double currentBalance;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const WholesaleCustomer({
    required this.id,
    required this.stationId,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.address,
    required this.creditLimit,
    required this.currentBalance,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  /// How much credit remains before hitting limit
  double get availableCredit => creditLimit - currentBalance;

  /// 0–100, clamped
  double get creditUsagePercent =>
      creditLimit > 0 ? (currentBalance / creditLimit * 100).clamp(0.0, 100.0) : 0;

  bool get isOverLimit => currentBalance >= creditLimit;

  /// Preferred display name — company first if set
  String get displayName =>
      (companyName != null && companyName!.isNotEmpty) ? companyName! : name;

  factory WholesaleCustomer.fromJson(Map<String, dynamic> json) => WholesaleCustomer(
        id: json['id'] as int,
        stationId: json['stationId'] as int,
        name: json['name'] as String,
        companyName: json['companyName'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        creditLimit: (json['creditLimit'] as num).toDouble(),
        currentBalance: (json['currentBalance'] as num).toDouble(),
        status: json['status'] as String,
        notes: json['notes'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
