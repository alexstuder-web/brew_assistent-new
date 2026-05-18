class VideoInstruction {
  final String id;
  final String userProfileId;
  final String title;
  final String youtubeUrl;
  final String? description;
  final int position;
  final DateTime createdAt;

  VideoInstruction({
    required this.id,
    required this.userProfileId,
    required this.title,
    required this.youtubeUrl,
    this.description,
    this.position = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_profile_id': userProfileId,
        'title': title,
        'youtube_url': youtubeUrl,
        'description': description,
        'position': position,
      };

  factory VideoInstruction.fromJson(Map<String, dynamic> json) => VideoInstruction(
        id: json['id'] as String,
        userProfileId: json['user_profile_id'] as String,
        title: json['title'] as String,
        youtubeUrl: json['youtube_url'] as String,
        description: json['description'] as String?,
        position: json['position'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
