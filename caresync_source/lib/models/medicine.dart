class Medicine {
  final int? id;
  final String name;
  final String dosage;
  final int totalStock;
  final int stockThreshold;
  final List<String>? timings;

  Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.totalStock,
    this.stockThreshold = 5,
    this.timings,
  });

  /// Senior Developer Tip: Use meaningful aliases for backwards compatibility
  int get stock => totalStock;
  String get time => (timings != null && timings!.isNotEmpty) ? timings!.first : "--:--";

  factory Medicine.fromJson(Map<String, dynamic> json) {
    // Handle both 'total_stock' (backend) and 'stock' (legacy/cloud)
    int stockValue = json['total_stock'] ?? json['stock'] ?? 0;
    
    // Handle timings which might be a comma-separated string from SQLite or a List from Firestore
    List<String> timingsList = [];
    if (json['timings'] != null) {
      if (json['timings'] is String) {
        timingsList = (json['timings'] as String).split(',');
      } else if (json['timings'] is List) {
        timingsList = List<String>.from(json['timings']);
      }
    }

    return Medicine(
      id: json['id'],
      name: json['medicine_name'] ?? json['name'] ?? 'Unknown',
      dosage: json['dosage'] ?? 'N/A',
      totalStock: stockValue,
      stockThreshold: json['stock_threshold'] ?? 5,
      timings: timingsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicine_name': name,
      'dosage': dosage,
      'total_stock': totalStock,
      'stock_threshold': stockThreshold,
      'timings': timings,
    };
  }
}
