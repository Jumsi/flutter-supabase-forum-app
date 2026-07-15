import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/posts_provider.dart';

class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch the initial batch of posts as soon as the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().refreshPosts();
    });

    // Listen to scroll movements to trigger pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<PostsProvider>().loadMorePosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthStateProvider>(context);
    final postsProvider = Provider.of<PostsProvider>(context);
    final isLoggedIn = authProvider.user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
        actions: [
          if (isLoggedIn) ...[
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged out successfully')),
                  );
                }
              },
            ),
          ] else ...[
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('Register'),
            ),
          ]
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => postsProvider.refreshPosts(),
        child: postsProvider.isLoading && postsProvider.posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : postsProvider.errorMessage != null && postsProvider.posts.isEmpty
            ? Center(child: Text('Error: ${postsProvider.errorMessage}'))
            : postsProvider.posts.isEmpty
            ? const Center(child: Text('No posts yet. Be the first to create one!'))
            : ListView.builder(
          controller: _scrollController,
          itemCount: postsProvider.posts.length + (postsProvider.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == postsProvider.posts.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final post = postsProvider.posts[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  post.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      post.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (post.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: post.imageUrls.length,
                          itemBuilder: (context, imgIndex) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  post.imageUrls[imgIndex],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 40),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ]
                  ],
                ),
                trailing: isLoggedIn && post.userId == authProvider.user?.id
                    ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => postsProvider.removePost(post.id),
                )
                    : null,
                onTap: () {
                  context.go('/post-detail', extra: post);
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // go_router will automatically handle route guarding and bounce guests to /login
          context.go('/create-post');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}