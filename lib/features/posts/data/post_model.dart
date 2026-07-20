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
    return PostModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorName: json['username'] ?? json['author_name'] ?? 'anonymous',
      userId: json['user_id'] ?? '',
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      commentsCount: json['comments_count'] is int ? json['comments_count'] : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'author_name': authorName,
      'user_id': userId,
      'image_urls': imageUrls,
      'comments_count': commentsCount,
    };
  }
}