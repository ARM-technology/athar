class PostModel {
  final String userID;
  final String username;
  final String title;
  final String content;
  final int likes;
  final int dislikes;
  final int comments;

  PostModel({
    required this.userID,
    required this.username,
    required this.title,
    required this.content,
    required this.likes,
    required this.dislikes,
    required this.comments,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      // sqlc بيرجع أسماء كابيتال أو سنيك كيس - نتعامل مع الاثنين
      userID: (json['UserID'] ?? json['user_id'] ?? json['userID'] ?? '').toString(),
      username: (json['Username'] ?? json['username'] ?? '').toString(),
      title: (json['Title'] ?? json['title'] ?? '').toString(),
      content: (json['Content'] ?? json['content'] ?? '').toString(),
      likes: json['LikesCount'] ?? json['likes_count'] ?? json['likes'] ?? 0,
      dislikes: json['DislikesCount'] ?? json['dislikes_count'] ?? json['dislikes'] ?? 0,
      comments: json['CommentsCount'] ?? json['comments_count'] ?? json['comments'] ?? 0,
    );
  }
}