import 'package:flutter/material.dart';

class RedditPostCard extends StatelessWidget {
  final String category;
  final String author;
  final String timeAgo;
  final String title;
  final String bodyPreview;
  final int upvotes;
  final int commentCount;
  final VoidCallback? onUpvote;
  final VoidCallback? onCommentTap;

  const RedditPostCard({
    super.key,
    required this.category,
    required this.author,
    required this.timeAgo,
    required this.title,
    required this.bodyPreview,
    required this.upvotes,
    required this.commentCount,
    this.onUpvote,
    this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A1A1B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF343536) : const Color(0xFFEDEFF1);
    final primaryTextColor = isDark ? const Color(0xFFD7DADC) : const Color(0xFF1C1C1C);
    final secondaryTextColor = isDark ? const Color(0xFF818384) : const Color(0xFF787C7E);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onCommentTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER (Metadata)
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.deepPurpleAccent,
                    child: Text(
                      category.isNotEmpty ? category[0].toUpperCase() : 'F',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "f/$category",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      " • Posted by u/$author • $timeAgo",
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. TITLE
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),

              // 3. BODY PREVIEW
              Text(
                bodyPreview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              Divider(color: borderColor, height: 1),
              const SizedBox(height: 8),

              // 4. ACTION FOOTER (Upvotes & Comments)
              Row(
                children: [
                  // Upvotes cluster
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF272729) : const Color(0xFFF6F7F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                          color: secondaryTextColor,
                          onPressed: onUpvote,
                        ),
                        Text(
                          '$upvotes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                          color: secondaryTextColor,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Comment Button
                  _buildFooterButton(
                    context,
                    icon: Icons.mode_comment_outlined,
                    label: "$commentCount Comments",
                    onTap: onCommentTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback? onTap,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFF818384) : const Color(0xFF787C7E);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF272729) : const Color(0xFFF6F7F8),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: secondaryTextColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}