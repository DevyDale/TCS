class Post {
  final int id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String postType;
  final String content;
  final String? media;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isModerated;
  final bool isFlagged;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.postType,
    required this.content,
    this.media,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isModerated,
    required this.isFlagged,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      authorId: json['author_id'],
      authorName: json['author_name'],
      authorAvatar: json['author_avatar'],
      postType: json['post_type'],
      content: json['content'],
      media: json['media'],
      likesCount: json['likes_count'],
      commentsCount: json['comments_count'],
      sharesCount: json['shares_count'],
      isModerated: json['is_moderated'],
      isFlagged: json['is_flagged'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
