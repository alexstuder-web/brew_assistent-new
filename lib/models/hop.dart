class Hop {
  final String? id;
  final String userProfileId;
  final String? brewfatherId;
  final String name;
  final double? alpha;
  final String? origin;
  final String? year;
  final double amount;
  final String? unit;
  final String? type; // Pellet, Cryo, etc.
  final String? notes;

  Hop({
    this.id,
    required this.userProfileId,
    this.brewfatherId,
    required this.name,
    this.alpha,
    this.origin,
    this.year,
    required this.amount,
    this.unit,
    this.type,
    this.notes,
  });

  factory Hop.fromJson(Map<String, dynamic> json) {
    return Hop(
      id: json['id'],
      userProfileId: json['user_profile_id'],
      brewfatherId: json['brewfather_id'],
      name: json['name'],
      alpha: (json['alpha'] as num?)?.toDouble(),
      origin: json['origin'],
      year: json['year'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'],
      type: json['type'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'brewfather_id': brewfatherId,
      'name': name,
      'alpha': alpha,
      'origin': origin,
      'year': year,
      'amount': amount,
      'unit': unit,
      'type': type,
      'notes': notes,
    };
  }

  factory Hop.fromBrewfather(Map<String, dynamic> bfData, String userProfileId) {
    // Inventory is priority, fall back to amount, though usually 'inventory' 
    // is what we want for stock.
    final amount = (bfData['inventory'] as num?)?.toDouble() ?? (bfData['amount'] as num?)?.toDouble() ?? 0.0;
    
    return Hop(
      userProfileId: userProfileId,
      brewfatherId: bfData['_id'],
      name: bfData['name'] ?? '',
      alpha: (bfData['alpha'] as num?)?.toDouble(),
      origin: bfData['origin'],
      year: bfData['year']?.toString(), // Sometimes year is int
      amount: amount,
      unit: bfData['amountUnit'] ?? 'g', // Hops usually in grams
      type: bfData['type'],
      notes: bfData['notes'],
    );
  }
}
