class Post {
  final int id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String authorRole;
  final String postType; // 'post' | 'fweet' | 'announcement' | 'arcade_clip'
  final String content;
  final String? media;
  final String? caption;
  final String visibility; // 'public' | 'followers' | 'private'
  final String? location;
  final List<String> taggedUsers;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByMe;
  final bool isModerated;
  final bool isFlagged;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorRole = 'student',
    required this.postType,
    required this.content,
    this.media,
    this.caption,
    this.visibility = 'public',
    this.location,
    this.taggedUsers = const [],
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    this.isLikedByMe = false,
    required this.isModerated,
    required this.isFlagged,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Derived helpers ──────────────────────────────────────────

  bool get hasMedia => media != null && media!.isNotEmpty;
  bool get hasLocation => location != null && location!.isNotEmpty;
  bool get isAnnouncement => postType == 'announcement';
  bool get isFweet => postType == 'fweet';
  bool get isArcadeClip => postType == 'arcade_clip';

  /// Human-readable relative time, e.g. "2h ago"
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  // ── Serialisation ────────────────────────────────────────────

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String,
      authorAvatar: json['author_avatar'] as String?,
      authorRole: json['author_role'] as String? ?? 'student',
      postType: json['post_type'] as String,
      content: json['content'] as String,
      media: json['media'] as String?,
      caption: json['caption'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      location: json['location'] as String?,
      taggedUsers: (json['tagged_users'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      sharesCount: json['shares_count'] as int? ?? 0,
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
      isModerated: json['is_moderated'] as bool? ?? false,
      isFlagged: json['is_flagged'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'author_name': authorName,
        'author_avatar': authorAvatar,
        'author_role': authorRole,
        'post_type': postType,
        'content': content,
        'media': media,
        'caption': caption,
        'visibility': visibility,
        'location': location,
        'tagged_users': taggedUsers,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'shares_count': sharesCount,
        'is_liked_by_me': isLikedByMe,
        'is_moderated': isModerated,
        'is_flagged': isFlagged,
        'is_pinned': isPinned,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Post copyWith({
    bool? isLikedByMe,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isPinned,
    bool? isFlagged,
  }) {
    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorRole: authorRole,
      postType: postType,
      content: content,
      media: media,
      caption: caption,
      visibility: visibility,
      location: location,
      taggedUsers: taggedUsers,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isModerated: isModerated,
      isFlagged: isFlagged ?? this.isFlagged,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}