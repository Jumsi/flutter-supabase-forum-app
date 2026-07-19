import 'package:flutter/material.dart';

class RedditPostCard extends StatelessWidget {
  final String category;
  final String author;
  final String timeAgo;
  final String title;
  final String bodyPreview;
  final int commentCount;
  final List<String> imageUrls;
  final VoidCallback? onCommentTap;

  const RedditPostCard({
    super.key,
    required this.category,
    required this.author,
    required this.timeAgo,
    required this.title,
    required this.bodyPreview,
    required this.commentCount,
    this.imageUrls = const [], // Default to an empty list
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

              // 3. BODY PREVIEW
              if (bodyPreview.isNotEmpty) ...[
                const SizedBox(height: 6),
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
              ],

              // 4. IMAGE GALLERY
              if (imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _FeedImageGallery(imageUrls: imageUrls),
              ],

              const SizedBox(height: 12),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 8),

              // 5. ACTION FOOTER (Only Comments)
              _buildFooterButton(
                context,
                icon: Icons.mode_comment_outlined,
                label: "$commentCount Comments",
                onTap: onCommentTap,
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
          mainAxisSize: MainAxisSize.min,
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

/// Image gallery logic moved inside the card component
class _FeedImageGallery extends StatelessWidget {
  final List<String> imageUrls;

  const _FeedImageGallery({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[index],
                fit: BoxFit.cover,
                width: 180,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 180,
                    color: Colors.black12,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 180,
                  color: Colors.black12,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}