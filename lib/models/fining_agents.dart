class FiningAgents {
  const FiningAgents({
    required this.userProfileId,
    this.irishMoss = false,
    this.whirlfloc = false,
    this.gelatin = false,
    this.biersol = false,
    this.polyclar = false,
    this.isinglass = false,
    this.bentonite = false,
    this.eggWhites = false,
    this.activatedCarbon = false,
    this.extras = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String userProfileId;
  final bool irishMoss;
  final bool whirlfloc;
  final bool gelatin;
  final bool biersol;
  final bool polyclar;
  final bool isinglass;
  final bool bentonite;
  final bool eggWhites;
  final bool activatedCarbon;
  final List<String> extras;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FiningAgents copyWith({
    bool? irishMoss,
    bool? whirlfloc,
    bool? gelatin,
    bool? biersol,
    bool? polyclar,
    bool? isinglass,
    bool? bentonite,
    bool? eggWhites,
    bool? activatedCarbon,
    List<String>? extras,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FiningAgents(
      userProfileId: userProfileId,
      irishMoss: irishMoss ?? this.irishMoss,
      whirlfloc: whirlfloc ?? this.whirlfloc,
      gelatin: gelatin ?? this.gelatin,
      biersol: biersol ?? this.biersol,
      polyclar: polyclar ?? this.polyclar,
      isinglass: isinglass ?? this.isinglass,
      bentonite: bentonite ?? this.bentonite,
      eggWhites: eggWhites ?? this.eggWhites,
      activatedCarbon: activatedCarbon ?? this.activatedCarbon,
      extras: extras ?? this.extras,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FiningAgents.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? value) =>
        value == null ? null : DateTime.tryParse(value);
    final extras = (json['extras'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    return FiningAgents(
      userProfileId: json['user_profile_id'] as String? ?? '',
      irishMoss: (json['irish_moss'] as bool?) ?? false,
      whirlfloc: (json['whirlfloc'] as bool?) ?? false,
      gelatin: (json['gelatin'] as bool?) ?? false,
      biersol: (json['biersol'] as bool?) ?? false,
      polyclar: (json['polyclar'] as bool?) ?? false,
      isinglass: (json['isinglass'] as bool?) ?? false,
      bentonite: (json['bentonite'] as bool?) ?? false,
      eggWhites: (json['egg_whites'] as bool?) ?? false,
      activatedCarbon: (json['activated_carbon'] as bool?) ?? false,
      extras: extras,
      createdAt: parse(json['created_at'] as String?),
      updatedAt: parse(json['updated_at'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_profile_id': userProfileId,
      'irish_moss': irishMoss,
      'whirlfloc': whirlfloc,
      'gelatin': gelatin,
      'biersol': biersol,
      'polyclar': polyclar,
      'isinglass': isinglass,
      'bentonite': bentonite,
      'egg_whites': eggWhites,
      'activated_carbon': activatedCarbon,
      'extras': extras,
    };
  }

  static FiningAgents empty(String userProfileId) =>
      FiningAgents(userProfileId: userProfileId);
}
