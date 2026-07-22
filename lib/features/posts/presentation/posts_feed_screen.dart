import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../reddit_post_card.dart';
import '../data/post_model.dart';
import '../providers/posts_provider.dart';
import 'edit_post_dialog.dart';

class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // 1. Initial fetch managed by the PostsProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().refreshPosts();
    });

    // 2. Setup scroll listener to manage infinite pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Triggers when user scrolls within 200 pixels of the bottom
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<PostsProvider>().loadMorePosts();
    }
  }

  // Helper method to format the timestamp into "6h ago", "2d ago", etc.
  String _getTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final difference = DateTime.now().difference(date);

    if (difference.inDays >= 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays >= 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await context.read<PostsProvider>().removePost(postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted!')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    }
  }

  void _showDeleteDialog(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.pop();
              _deletePost(post.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _supabase.auth.currentUser?.id;

    // 3. Keep an active watch on your PostsProvider state
    final postsProvider = context.watch<PostsProvider>();
    final posts = postsProvider.posts;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF030303) : const Color(0xFFDAE0E6),
      appBar: AppBar(
        title: const Text('f/ForumFeed', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => postsProvider.refreshPosts(),
          ),
          if (userId != null) ...[
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () async {
                await _supabase.auth.signOut();
                if (!mounted) return;
                context.go('/login');
              },
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.login_rounded, size: 20, color: Colors.deepPurpleAccent),
                label: const Text('Login', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                onPressed: () => context.go('/login'),
              ),
            ),
          ],
        ],
      ),
      body: postsProvider.isLoading && posts.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : posts.isEmpty
          ? Center(child: Text('No posts yet!', style: TextStyle(color: Colors.grey[600])))
          : RefreshIndicator(
        onRefresh: () => postsProvider.refreshPosts(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: posts.length + (postsProvider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == posts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
                  );
                }

                final post = posts[index];
                final isOwner = post.userId == userId;

                return Stack(
                  children: [
                    RedditPostCard(
                      category: 'general',
                      author: post.authorName,
                      // 👈 FIX: Calculate accurate time dynamically instead of hardcoding
                      timeAgo: _getTimeAgo(post.createdAt),
                      title: post.title,
                      bodyPreview: post.content,
                      commentCount: post.commentsCount,
                      imageUrls: post.imageUrls,
                      onCommentTap: () {
                        context.push('/post-detail', extra: post).then((_) {
                          postsProvider.refreshPosts();
                        });
                      },
                    ),
                    if (isOwner)
                      Positioned(
                        top: 18,
                        right: 24,
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz, color: isDark ? Colors.white54 : Colors.black54),
                          onSelected: (value) {
                            if (value == 'edit') {
                              showDialog(
                                context: context,
                                builder: (context) => EditPostDialog(post: post),
                              );
                            } else if (value == 'delete') {
                              _showDeleteDialog(post);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurpleAccent,
        onPressed: () => context.push('/create-post').then((_) {
          postsProvider.refreshPosts();
        }),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}