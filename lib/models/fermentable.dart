class Fermentable {
  final String? id;
  final String userProfileId;
  final String? brewfatherId;
  final String name;
  final String? supplier;
  final double amount;
  final String? unit;

  final String? type;
  final double? potential;
  final double? yield;
  final double? attenuation;
  final String? notes;

  Fermentable({
    this.id,
    required this.userProfileId,
    this.brewfatherId,
    required this.name,
    this.supplier,
    required this.amount,
    this.unit,
    this.type,
    this.potential,
    this.yield,
    this.attenuation,
    this.notes,
  });

  factory Fermentable.fromJson(Map<String, dynamic> json) {
    return Fermentable(
      id: json['id'],
      userProfileId: json['user_profile_id'],
      brewfatherId: json['brewfather_id'],
      name: json['name'],
      supplier: json['supplier'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'],
      type: json['type'],
      potential: (json['potential'] as num?)?.toDouble(),
      yield: (json['yield'] as num?)?.toDouble(),
      attenuation: (json['attenuation'] as num?)?.toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'brewfather_id': brewfatherId,
      'name': name,
      'supplier': supplier,
      'amount': amount,
      'unit': unit,
      'type': type,
      'potential': potential,
      'yield': yield,
      'attenuation': attenuation,
      'notes': notes,
    };
  }

  factory Fermentable.fromBrewfather(Map<String, dynamic> bfData, String userProfileId) {
    // Inventory is priority, fall back to amount
    final amount = (bfData['inventory'] as num?)?.toDouble() ?? (bfData['amount'] as num?)?.toDouble() ?? 0.0;
    
    return Fermentable(
      userProfileId: userProfileId,
      brewfatherId: bfData['_id'],
      name: bfData['name'] ?? '',
      supplier: bfData['supplier'],
      amount: amount,
      unit: bfData['amountUnit'] ?? 'kg',
      type: bfData['type'],
      potential: (bfData['potential'] as num?)?.toDouble(),
      yield: (bfData['yield'] as num?)?.toDouble(),
      attenuation: (bfData['attenuation'] as num?)?.toDouble(),
      notes: bfData['notes'],
    );
  }
}
