enum TapType { standard, ale, stout }

enum GasType { co2, nitro, mixed }

class TapConfig {
  final int tapNumber;
  final TapType tapType;
  final GasType gasType;
  final String? beerName;
  final DateTime? tappedAt;
  final DateTime? bestBefore;

  TapConfig({
    required this.tapNumber,
    this.tapType = TapType.standard,
    this.gasType = GasType.co2,
    this.beerName,
    this.tappedAt,
    this.bestBefore,
  });

  factory TapConfig.fromJson(Map<String, dynamic> json) {
    return TapConfig(
      tapNumber: json['tapNumber'] ?? 0,
      tapType: TapType.values.firstWhere(
        (e) => e.name == json['tapType'],
        orElse: () => TapType.standard,
      ),
      gasType: GasType.values.firstWhere(
        (e) => e.name == json['gasType'],
        orElse: () => GasType.co2,
      ),
      beerName: json['beerName'],
      tappedAt: json['tappedAt'] != null ? DateTime.parse(json['tappedAt']) : null,
      bestBefore: json['bestBefore'] != null ? DateTime.parse(json['bestBefore']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tapNumber': tapNumber,
      'tapType': tapType.name,
      'gasType': gasType.name,
      'beerName': beerName,
      'tappedAt': tappedAt?.toIso8601String(),
      'bestBefore': bestBefore?.toIso8601String(),
    };
  }

  TapConfig copyWith({
    int? tapNumber,
    TapType? tapType,
    GasType? gasType,
    String? beerName,
    DateTime? tappedAt,
    DateTime? bestBefore,
  }) {
    return TapConfig(
      tapNumber: tapNumber ?? this.tapNumber,
      tapType: tapType ?? this.tapType,
      gasType: gasType ?? this.gasType,
      beerName: beerName ?? this.beerName,
      tappedAt: tappedAt ?? this.tappedAt,
      bestBefore: bestBefore ?? this.bestBefore,
    );
  }

  DateTime? suggestBestBefore() {
    if (tappedAt == null) return null;
    // Simple logic: 90 days for most beers
    return tappedAt!.add(const Duration(days: 90));
  }
}

class KeezerConfig {
  final String userProfileId;
  final int numTaps;
  final List<TapConfig> taps;

  KeezerConfig({
    required this.userProfileId,
    required this.numTaps,
    required this.taps,
  });

  factory KeezerConfig.fromJson(Map<String, dynamic> json) {
    var tapsList = (json['taps'] as List? ?? [])
        .map((t) => TapConfig.fromJson(t as Map<String, dynamic>))
        .toList();
    return KeezerConfig(
      userProfileId: json['user_profile_id'],
      numTaps: json['num_taps'] ?? 0,
      taps: tapsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_profile_id': userProfileId,
      'num_taps': numTaps,
      'taps': taps.map((t) => t.toJson()).toList(),
    };
  }
}
