class Misc {
  final String? id;
  final String userProfileId;
  final String? brewfatherId;
  final String name;
  final double amount;
  final String? unit;
  final String? type;
  final String? use;
  final double? time;
  final String? notes;

  Misc({
    this.id,
    required this.userProfileId,
    this.brewfatherId,
    required this.name,
    required this.amount,
    this.unit,
    this.type,
    this.use,
    this.time,
    this.notes,
  });

  factory Misc.fromJson(Map<String, dynamic> json) {
    return Misc(
      id: json['id'],
      userProfileId: json['user_profile_id'],
      brewfatherId: json['brewfather_id'],
      name: json['name'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'],
      type: json['type'],
      use: json['use'], // 'use' is reserved keyword in SQL but fine here, careful with DB mapping
      time: (json['time'] as num?)?.toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'brewfather_id': brewfatherId,
      'name': name,
      'amount': amount,
      'unit': unit,
      'type': type,
      'use': use,
      'time': time,
      'notes': notes,
    };
  }

  factory Misc.fromBrewfather(Map<String, dynamic> bfData, String userProfileId) {
    // Inventory is priority
    final amount = (bfData['inventory'] as num?)?.toDouble() ?? (bfData['amount'] as num?)?.toDouble() ?? 0.0;
    
    return Misc(
      userProfileId: userProfileId,
      brewfatherId: bfData['_id'],
      name: bfData['name'] ?? '',
      amount: amount,
      unit: bfData['amountUnit'] ?? bfData['unit'] ?? 'g', 
      type: bfData['type'],
      use: bfData['use'],
      time: (bfData['time'] as num?)?.toDouble(),
      notes: bfData['notes'],
    );
  }
}
