class PostModel {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final String userId;
  final List<String> imageUrls;
  final DateTime? createdAt;
  final int commentsCount;

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.userId,
    required this.imageUrls,
    this.createdAt,
    required this.commentsCount,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Safely extract comment count whether it's a flat count or a nested relation count
    int parsedCommentCount = 0;
    if (json['comments_count'] is int) {
      parsedCommentCount = json['comments_count'];
    } else if (json['comments'] is List && (json['comments'] as List).isNotEmpty) {
      final firstComment = (json['comments'] as List).first;
      if (firstComment is Map && firstComment['count'] is int) {
        parsedCommentCount = firstComment['count'];
      }
    }

    return PostModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorName: json['username'] ?? json['author_name'] ?? 'anonymous',
      userId: json['user_id'] ?? '',
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      commentsCount: parsedCommentCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'username': authorName,
      'user_id': userId,
      'image_urls': imageUrls,
    };
  }
}