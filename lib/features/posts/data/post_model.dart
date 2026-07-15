class PostModel {
  final String id;
  final String userId;
  final String title;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
  });

  // Convert Supabase Map (JSON) into a PostModel object
  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convert PostModel object to Map (JSON) to save to Supabase
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'image_urls': imageUrls,
      if (id.isNotEmpty) 'id': id,
      if (userId.isNotEmpty) 'user_id': userId,
    };
  }
}