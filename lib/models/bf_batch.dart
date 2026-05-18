class BfBatch {
  final String? id;
  final String userProfileId;
  final String? brewfatherId;
  final String name;
  final int? batchNo;
  final String? status;
  final int? brewDate; // Milliseconds
  final String? recipeName;
  final Map<String, dynamic> data;
  Map<String, dynamic> raptData;
  Map<String, dynamic> analysisData;

  BfBatch({
    this.id,
    required this.userProfileId,
    this.brewfatherId,
    required this.name,
    this.batchNo,
    this.status,
    this.brewDate,
    this.recipeName,
    required this.data,
    Map<String, dynamic>? raptData,
    Map<String, dynamic>? analysisData,
  }) : raptData = raptData ?? {},
       analysisData = analysisData ?? {};

  factory BfBatch.fromJson(Map<String, dynamic> json) {
    return BfBatch(
      id: json['id'],
      userProfileId: json['user_profile_id'],
      brewfatherId: json['brewfather_id'],
      name: json['name'],
      batchNo: json['batch_no'],
      status: json['status'],
      brewDate: (json['brew_date'] as num?)?.toInt(),
      recipeName: json['recipe_name'],
      data: json['data'] ?? {},
      raptData: Map<String, dynamic>.from(json['rapt_data'] ?? {}),
      analysisData: Map<String, dynamic>.from(json['analysis_data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'brewfather_id': brewfatherId,
      'name': name,
      'batch_no': batchNo,
      'status': status,
      'brew_date': brewDate,
      'recipe_name': recipeName,
      'data': data,
      'rapt_data': raptData,
      'analysis_data': analysisData,
    };
  }

  factory BfBatch.fromBrewfather(Map<String, dynamic> bfData, String userProfileId) {
    String displayName = bfData['name'] ?? 'Unbenannt';
    
    // User requested to prioritize 'title' field if available (e.g. from custom views or specific API responses)
    if (bfData['title'] != null && (bfData['title'] as String).isNotEmpty) {
      displayName = bfData['title'];
    } else {
        // Fallback: If name says "Sud", or "Batch", try to find a better title from events or construct it.
        // "Sud" seems to be a generic default in some locales or user settings.
        if (displayName == 'Sud' || displayName.startsWith('Batch #')) {
             // 1. Try to find brew day event title which is usually descriptive
             if (bfData['events'] != null && bfData['events'] is List) {
                 for (var e in bfData['events']) {
                     if (e['eventType'] == 'event-batch-brew-day' && e['title'] != null) {
                         displayName = e['title'];
                         break;
                     }
                 }
             }
        }
    }

    // Safety fallback if still generic "Sud"
    if (displayName == 'Sud') {
       var rName = bfData['recipe']?['name'] ?? 'Unbekannt';
       var bNo = bfData['batchNo'] ?? '?';
       displayName = '$rName #$bNo';
    }

    return BfBatch(
      userProfileId: userProfileId,
      brewfatherId: bfData['_id'] ?? bfData['id'],
      name: displayName,
      batchNo: (bfData['batchNo'] as num?)?.toInt(),
      status: bfData['status'],
      brewDate: (bfData['brewDate'] as num?)?.toInt(),
      recipeName: bfData['recipe']?['name'],
      data: bfData,
    );
  }
}
