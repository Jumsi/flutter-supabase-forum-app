import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/post_model.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _commentController = TextEditingController();

  late int _upvotes;
  int _myVote = 0;

  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    // Assuming post model has upvotesCount. Update if property name differs.
    _upvotes = 0;
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final List<dynamic> response = await _supabase
          .from('comments')
          .select('*')
          .eq('post_id', widget.post.id)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _comments = List<Map<String, dynamic>>.from(response);
        _isLoadingComments = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingComments = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading comments: $error')),
      );
    }
  }

  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      final user = _supabase.auth.currentUser;
      final emailPrefix = user?.email?.split('@')[0] ?? 'user';
      final String userNickname = user?.userMetadata?['nickname'] ?? emailPrefix;

      await _supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': user?.id,
        'username': userNickname,
        'content': commentText,
      });

      await _supabase
          .from('posts')
          .update({'comments_count': _comments.length + 1})
          .eq('id', widget.post.id);

      _commentController.clear();
      FocusScope.of(context).unfocus();
      _fetchComments();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit comment: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _handleVote(int voteType) async {
    final originalUpvotes = _upvotes;
    final originalMyVote = _myVote;

    setState(() {
      if (_myVote == voteType) {
        _upvotes -= voteType;
        _myVote = 0;
      } else {
        int diff = voteType - _myVote;
        _upvotes += diff;
        _myVote = voteType;
      }
    });

    try {
      await _supabase
          .from('posts')
          .update({'upvotes_count': _upvotes})
          .eq('id', widget.post.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _myVote = originalMyVote;
        _upvotes = originalUpvotes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save vote: $error')),
      );
    }
  }

  String _getTimeDisplay(dynamic createdAt) {
    if (createdAt == null) return 'Just now';
    try {
      final DateTime date = createdAt is String ? DateTime.parse(createdAt) : createdAt;
      final difference = DateTime.now().difference(date);
      if (difference.inDays > 0) return '${difference.inDays}d ago';
      if (difference.inHours > 0) return '${difference.inHours}h ago';
      if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    } catch (_) {}
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF030303) : const Color(0xFFDAE0E6);
    final cardColor = isDark ? const Color(0xFF1A1A1B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF343536) : const Color(0xFFEDEFF1);
    final primaryTextColor = isDark ? const Color(0xFFD7DADC) : const Color(0xFF1C1C1C);
    final secondaryTextColor = isDark ? const Color(0xFF818384) : const Color(0xFF787C7E);
    final primaryColor = Colors.deepPurpleAccent;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('f/Post Details'),
          centerTitle: false,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: primaryColor,
                                child: const Text('G', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Text("f/general", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryTextColor)),
                              Expanded(
                                child: Text(
                                  " • Posted by u/${widget.post.authorName ?? 'anonymous'} • ${_getTimeDisplay(widget.post.createdAt)}",
                                  style: TextStyle(fontSize: 12, color: secondaryTextColor, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(widget.post.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor, height: 1.3)),
                          const SizedBox(height: 14),
                          Text(widget.post.content, style: TextStyle(fontSize: 15, color: primaryTextColor, height: 1.5)),
                          const SizedBox(height: 20),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
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
                                      icon: Icon(Icons.arrow_upward_rounded, size: 22, color: _myVote == 1 ? Colors.orange : secondaryTextColor),
                                      onPressed: () => _handleVote(1),
                                    ),
                                    Text(
                                      '$_upvotes',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _myVote == 1 ? Colors.orange : _myVote == -1 ? Colors.blue : primaryTextColor,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      icon: Icon(Icons.arrow_downward_rounded, size: 22, color: _myVote == -1 ? Colors.blue : secondaryTextColor),
                                      onPressed: () => _handleVote(-1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Comments (${_comments.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor)),
                          const SizedBox(height: 12),
                          if (_isLoadingComments)
                            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.deepPurpleAccent)))
                          else if (_comments.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, color: secondaryTextColor, size: 36),
                                    const SizedBox(height: 8),
                                    Text('No comments yet. Be the first to share your thoughts!', textAlign: TextAlign.center, style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _comments.length,
                              separatorBuilder: (_, __) => Divider(color: borderColor, height: 24),
                              itemBuilder: (_, index) {
                                final comment = _comments[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: Colors.grey[400],
                                          child: Text(
                                            comment['username']?.isNotEmpty == true ? comment['username'][0].toUpperCase() : 'U',
                                            style: const TextStyle(fontSize: 8, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text("u/${comment['username'] ?? 'anonymous'}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor)),
                                        const SizedBox(width: 6),
                                        Text("• ${_getTimeDisplay(comment['created_at'])}", style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(comment['content'] ?? '', style: TextStyle(fontSize: 14, color: primaryTextColor, height: 1.3)),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(color: cardColor, border: Border(top: BorderSide(color: borderColor))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF272729) : const Color(0xFFF6F7F8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSubmittingComment
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent),
                  )
                      : IconButton(onPressed: _submitComment, icon: Icon(Icons.send_rounded, color: primaryColor))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}