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
      final List<dynamic> response = await _supabase
          .from('posts')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _posts = List<Map<String, dynamic>>.from(response);
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

  Future<void> _handleUpvote(int index, Map<String, dynamic> post) async {
    final currentUpvotes = post['upvotes_count'] ?? 0;
    final newUpvotes = currentUpvotes + 1;

    setState(() => _posts[index]['upvotes_count'] = newUpvotes);

    try {
      await _supabase
          .from('posts')
          .update({'upvotes_count': newUpvotes})
          .eq('id', post['id']);
    } catch (error) {
      setState(() => _posts[index]['upvotes_count'] = currentUpvotes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save upvote: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: ListView.builder(
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            final post = _posts[index];

            // Fix: Map the DB 'username' to 'author_name' for the model
            final postMap = Map<String, dynamic>.from(post);
            postMap['author_name'] = post['username'] ?? 'anonymous';
            final postModel = PostModel.fromJson(postMap);

            return RedditPostCard(
              category: post['category'] ?? 'general',
              author: post['username'] ?? 'anonymous',
              timeAgo: 'Just now', // Simplified for display
              title: post['title'] ?? 'Untitled',
              bodyPreview: post['content'] ?? '',
              upvotes: post['upvotes_count'] ?? 0,
              commentCount: post['comments_count'] ?? 0,
              onUpvote: () => _handleUpvote(index, post),
              onCommentTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PostDetailScreen(post: postModel)),
                ).then((shouldReload) {
                  if (shouldReload == true) _fetchPosts();
                });
              },
            );
          },
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