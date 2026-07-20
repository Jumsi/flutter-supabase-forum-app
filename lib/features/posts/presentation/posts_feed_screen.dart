import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../reddit_post_card.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/post_model.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // UPDATED: Added comments(count) to the select query
      final List<dynamic> postResponse = await _supabase
          .from('posts')
          .select('*, comments(count)')
          .order('created_at', ascending: false);

      setState(() {
        _posts = List<Map<String, dynamic>>.from(postResponse);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading posts: $error'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _supabase.from('posts').delete().eq('id', postId);
      _fetchPosts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted!')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    }
  }

  void _showDeleteDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(post['id']);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> post) {
    final titleController = TextEditingController(text: post['title']);
    final contentController = TextEditingController(text: post['content']);
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(labelText: 'Content'),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isUpdating ? null : () async {
                    setDialogState(() => isUpdating = true);
                    try {
                      await _supabase.from('posts').update({
                        'title': titleController.text.trim(),
                        'content': contentController.text.trim(),
                      }).eq('id', post['id']);

                      if (!mounted) return;
                      Navigator.pop(context);
                      _fetchPosts();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post updated successfully!')));
                    } catch (error) {
                      setDialogState(() => isUpdating = false);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $error')));
                    }
                  },
                  child: isUpdating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF030303) : const Color(0xFFDAE0E6),
      appBar: AppBar(
        title: const Text('f/ForumFeed', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchPosts),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : _posts.isEmpty
          ? Center(child: Text('No posts yet!', style: TextStyle(color: Colors.grey[600])))
          : RefreshIndicator(
        onRefresh: _fetchPosts,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                final postMap = Map<String, dynamic>.from(post);
                postMap['author_name'] = post['username'] ?? 'anonymous';
                final postModel = PostModel.fromJson(postMap);

                final isOwner = post['user_id'] == userId;

                // Extract image URLs safely
                final List<String> imageUrls = List<String>.from(post['image_urls'] ?? []);

                // UPDATED: Dynamically extract the comment count from the nested Supabase relation
                int dynamicCommentCount = 0;
                if (post['comments'] != null && (post['comments'] as List).isNotEmpty) {
                  dynamicCommentCount = post['comments'][0]['count'] as int;
                }

                return Stack(
                  children: [
                    RedditPostCard(
                      category: post['category'] ?? 'general',
                      author: post['username'] ?? 'anonymous',
                      timeAgo: 'Just now',
                      title: post['title'] ?? 'Untitled',
                      bodyPreview: post['content'] ?? '',
                      commentCount: dynamicCommentCount, // UPDATED: Use the parsed dynamic count
                      imageUrls: imageUrls,
                      onCommentTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PostDetailScreen(post: postModel)),
                        ).then((shouldReload) {
                          if (shouldReload == true) _fetchPosts();
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
                              _showEditDialog(post);
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostScreen()))
            .then((shouldReload) => shouldReload == true ? _fetchPosts() : null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}