import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isLoading = false;
  bool _isAnonymous = false;
  String _userNickname = 'user';

  @override
  void initState() {
    super.initState();
    _loadUserNickname();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Loads the registered nickname from Supabase metadata
  Future<void> _loadUserNickname() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        // Fetches 'nickname' from secure user metadata. Fallback is the email prefix.
        final emailPrefix = user.email != null ? user.email!.split('@')[0] : 'user';
        _userNickname = user.userMetadata?['nickname'] ?? emailPrefix;
      });
    }
  }

  /// Publishes the post
  Future<void> _publishPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      final String authorToSave = _isAnonymous ? 'anonymous' : _userNickname;

      // Perfectly matches your newly updated Supabase schema!
      await _supabase.from('posts').insert({
        'title': title,
        'content': content,
        'user_id': user?.id,
        'username': authorToSave, // Saves 'anonymous' or the user's nickname
        'image_urls': [], // Empty array for your text[] column
      });

      if (!mounted) return;
      Navigator.pop(context, true); // Go back and trigger refresh on the feed
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating post: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Colors.deepPurpleAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mind / Description Field
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: "What's on your mind?",
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // NICKNAME / ANONYMOUS SLIDER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAnonymous ? Icons.visibility_off_outlined : Icons.face_rounded,
                    color: _isAnonymous ? Colors.grey : primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Post Anonymously',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _isAnonymous
                              ? "Posting as u/anonymous"
                              : "Posting publicly as u/$_userNickname",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAnonymous,
                    activeColor: primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _isAnonymous = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: _isLoading ? null : _publishPost,
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Publish Post',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}