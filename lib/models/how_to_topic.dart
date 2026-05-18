import 'package:uuid/uuid.dart';

class HowToPageData {
  final String id;
  final String title;
  final String content;

  HowToPageData({
    required this.id,
    required this.title,
    this.content = '',
  });

  factory HowToPageData.create({required String title, String content = ''}) {
    return HowToPageData(
      id: const Uuid().v4(),
      title: title,
      content: content,
    );
  }

  factory HowToPageData.fromJson(Map<String, dynamic> json) {
    return HowToPageData(
      id: json['id'] ?? const Uuid().v4(),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
    };
  }

  HowToPageData copyWith({
    String? title,
    String? content,
  }) {
    return HowToPageData(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }
}

class HowToTopic {
  final String id;
  final String userProfileId;
  final String title;
  final List<HowToPageData> pages;
  final int position;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HowToTopic({
    required this.id,
    required this.userProfileId,
    required this.title,
    this.pages = const [],
    this.position = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory HowToTopic.create({
    required String userProfileId,
    required String title,
    List<HowToPageData> pages = const [],
    int position = 0,
  }) {
    return HowToTopic(
      id: const Uuid().v4(),
      userProfileId: userProfileId,
      title: title,
      pages: pages,
      position: position,
    );
  }

  factory HowToTopic.fromJson(Map<String, dynamic> json) {
    // Legacy support: if 'content' exists but 'pages' is empty, migrate it
    List<HowToPageData> pages = [];
    if (json['pages'] != null) {
      pages = (json['pages'] as List).map((p) => HowToPageData.fromJson(p)).toList();
    } else if (json['content'] != null && (json['content'] as String).isNotEmpty) {
      pages = [
        HowToPageData(
          id: const Uuid().v4(),
          title: 'Hauptseite',
          content: json['content'],
        )
      ];
    }

    return HowToTopic(
      id: json['id'],
      userProfileId: json['user_profile_id'],
      title: json['title'] ?? '',
      pages: pages,
      position: json['position'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_profile_id': userProfileId,
      'title': title,
      'pages': pages.map((p) => p.toJson()).toList(),
      'position': position,
      // We don't send 'content' anymore, it's inside pages.
    };
  }

  HowToTopic copyWith({
    String? title,
    List<HowToPageData>? pages,
    int? position,
  }) {
    return HowToTopic(
      id: id,
      userProfileId: userProfileId,
      title: title ?? this.title,
      pages: pages ?? this.pages,
      position: position ?? this.position,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
