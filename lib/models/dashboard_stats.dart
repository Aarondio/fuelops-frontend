class DashboardStats {
  final DashboardToday today;
  final DashboardInventory inventory;
  final DashboardCredit credit;
  final DashboardMtd monthToDate;

  const DashboardStats({
    required this.today,
    required this.inventory,
    required this.credit,
    required this.monthToDate,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      today: DashboardToday.fromJson(json['today'] as Map<String, dynamic>),
      inventory: DashboardInventory.fromJson(json['inventory'] as Map<String, dynamic>),
      credit: DashboardCredit.fromJson(json['credit'] as Map<String, dynamic>),
      monthToDate: DashboardMtd.fromJson(json['monthToDate'] as Map<String, dynamic>),
    );
  }
}

class DashboardToday {
  final int salesCount;
  final double salesRevenue;
  final double salesVolume;
  final int wholesaleCount;
  final double wholesaleRevenue;
  final double wholesaleVolume;
  final int deliveriesCount;
  final double deliveriesVolume;
  final double deliveriesValue;
  final double volumeSold;
  final double totalRevenue;

  const DashboardToday({
    required this.salesCount,
    required this.salesRevenue,
    required this.salesVolume,
    required this.wholesaleCount,
    required this.wholesaleRevenue,
    required this.wholesaleVolume,
    required this.deliveriesCount,
    required this.deliveriesVolume,
    required this.deliveriesValue,
    required this.volumeSold,
    required this.totalRevenue,
  });

  factory DashboardToday.fromJson(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>;
    final wholesale = json['wholesale'] as Map<String, dynamic>;
    final deliveries = json['deliveries'] as Map<String, dynamic>;
    return DashboardToday(
      salesCount: (sales['count'] as num).toInt(),
      salesRevenue: (sales['revenue'] as num).toDouble(),
      salesVolume: (sales['volume'] as num).toDouble(),
      wholesaleCount: (wholesale['count'] as num).toInt(),
      wholesaleRevenue: (wholesale['revenue'] as num).toDouble(),
      wholesaleVolume: (wholesale['volume'] as num).toDouble(),
      deliveriesCount: (deliveries['count'] as num).toInt(),
      deliveriesVolume: (deliveries['volume'] as num).toDouble(),
      deliveriesValue: (deliveries['value'] as num).toDouble(),
      volumeSold: (json['volumeSold'] as num).toDouble(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
    );
  }
}

class DashboardInventory {
  final double totalLevel;
  final double totalCapacity;
  final double percentage;
  final Map<String, ProductInventory> byProduct;

  const DashboardInventory({
    required this.totalLevel,
    required this.totalCapacity,
    required this.percentage,
    required this.byProduct,
  });

  factory DashboardInventory.fromJson(Map<String, dynamic> json) {
    final byProductRaw = json['byProduct'] as Map<String, dynamic>? ?? {};
    final byProduct = byProductRaw.map((k, v) =>
        MapEntry(k, ProductInventory.fromJson(v as Map<String, dynamic>)));
    return DashboardInventory(
      totalLevel: (json['totalLevel'] as num).toDouble(),
      totalCapacity: (json['totalCapacity'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      byProduct: byProduct,
    );
  }
}

class ProductInventory {
  final double level;
  final double capacity;
  final double percentage;

  const ProductInventory({
    required this.level,
    required this.capacity,
    required this.percentage,
  });

  factory ProductInventory.fromJson(Map<String, dynamic> json) {
    return ProductInventory(
      level: (json['level'] as num).toDouble(),
      capacity: (json['capacity'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class DashboardCredit {
  final double retailOutstanding;
  final double wholesaleOutstanding;
  final double totalOutstanding;

  const DashboardCredit({
    required this.retailOutstanding,
    required this.wholesaleOutstanding,
    required this.totalOutstanding,
  });

  factory DashboardCredit.fromJson(Map<String, dynamic> json) {
    return DashboardCredit(
      retailOutstanding: (json['retailOutstanding'] as num).toDouble(),
      wholesaleOutstanding: (json['wholesaleOutstanding'] as num).toDouble(),
      totalOutstanding: (json['totalOutstanding'] as num).toDouble(),
    );
  }
}

class DashboardMtd {
  final int salesCount;
  final double salesRevenue;
  final int wholesaleCount;
  final double wholesaleRevenue;
  final double totalRevenue;

  const DashboardMtd({
    required this.salesCount,
    required this.salesRevenue,
    required this.wholesaleCount,
    required this.wholesaleRevenue,
    required this.totalRevenue,
  });

  factory DashboardMtd.fromJson(Map<String, dynamic> json) {
    return DashboardMtd(
      salesCount: (json['salesCount'] as num).toInt(),
      salesRevenue: (json['salesRevenue'] as num).toDouble(),
      wholesaleCount: (json['wholesaleCount'] as num).toInt(),
      wholesaleRevenue: (json['wholesaleRevenue'] as num).toDouble(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
    );
  }
}
