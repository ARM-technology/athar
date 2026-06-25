import 'package:flutter/material.dart';




class AllWidgets{

 static  Widget postWidget({
    required String name,
    required String userId,
    required String title,
    required String content,
    required int likes,
    required int dislikes,
    required int comments,
    VoidCallback? onLike,
    VoidCallback? onDislike,
    VoidCallback? onComment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// User Info
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            "@$userId",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 12),

          /// Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          /// Post Content
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          /// Actions
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceAround,
            children: [

              InkWell(
                onTap: onLike,
                child: Row(
                  children: [
                    const Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text("$likes"),
                  ],
                ),
              ),

              InkWell(
                onTap: onDislike,
                child: Row(
                  children: [
                    const Icon(
                      Icons.thumb_down_alt_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text("$dislikes"),
                  ],
                ),
              ),

              InkWell(
                onTap: onComment,
                child: Row(
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text("$comments"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}