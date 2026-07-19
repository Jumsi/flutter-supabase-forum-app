import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../data/post_model.dart';

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
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(imageUrls[index], fit: BoxFit.cover, width: 180),
          ),
        ),
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _comments = [];
  List<XFile> _selectedImages = [];
  bool _isLoadingComments = true;
  bool _isSubmittingComment = false;

  // NOTE: Replace 'images' with your actual Supabase Storage bucket name
  final String _storageBucket = 'images';

  @override
  void initState() {
    super.initState();
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

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    List<String> uploadedUrls = [];
    for (var image in images) {
      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final filePath = 'comments/$fileName';

      await _supabase.storage.from(_storageBucket).uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$fileExt'),
      );

      final publicUrl = _supabase.storage.from(_storageBucket).getPublicUrl(filePath);
      uploadedUrls.add(publicUrl);
    }
    return uploadedUrls;
  }

  String _getStoragePathFromUrl(String url) {
    // Extracts the folder/filename from the full public URL for deletion
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    final bucketIndex = pathSegments.indexOf(_storageBucket);
    if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
      return pathSegments.sublist(bucketIndex + 1).join('/');
    }
    return '';
  }

  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty && _selectedImages.isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      final user = _supabase.auth.currentUser;
      final emailPrefix = user?.email?.split('@')[0] ?? 'user';
      final String userNickname = user?.userMetadata?['nickname'] ?? emailPrefix;

      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages(_selectedImages);
      }

      await _supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': user?.id,
        'username': userNickname,
        'content': commentText,
        'image_urls': imageUrls, // Save images to database
      });

      await _supabase
          .from('posts')
          .update({'comments_count': _comments.length + 1})
          .eq('id', widget.post.id);

      _commentController.clear();
      setState(() => _selectedImages.clear());
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

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    try {
      // 1. Delete associated images from storage first
      final List<String> commentImages = List<String>.from(comment['image_urls'] ?? []);
      if (commentImages.isNotEmpty) {
        List<String> pathsToDelete = commentImages
            .map((url) => _getStoragePathFromUrl(url))
            .where((path) => path.isNotEmpty)
            .toList();

        if (pathsToDelete.isNotEmpty) {
          await _supabase.storage.from(_storageBucket).remove(pathsToDelete);
        }
      }

      // 2. Delete the comment from DB
      await _supabase.from('comments').delete().eq('id', comment['id']);

      final newCount = (_comments.length - 1).clamp(0, 99999);
      await _supabase.from('posts').update({'comments_count': newCount}).eq('id', widget.post.id);

      _fetchComments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment deleted!')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    }
  }

  void _showDeleteCommentDialog(Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(comment);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditCommentDialog(Map<String, dynamic> comment) {
    final contentController = TextEditingController(text: comment['content']);
    List<String> existingImages = List<String>.from(comment['image_urls'] ?? []);
    List<XFile> newImages = [];
    List<String> imagesToDelete = [];
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Comment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(labelText: 'Comment'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),

                    // Show existing images
                    if (existingImages.isNotEmpty) ...[
                      const Align(alignment: Alignment.centerLeft, child: Text("Current Images:", style: TextStyle(fontSize: 12))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: existingImages.map((url) => Stack(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover)),
                            Positioned(
                              right: 0, top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    existingImages.remove(url);
                                    imagesToDelete.add(url);
                                  });
                                },
                                child: Container(color: Colors.black54, child: const Icon(Icons.close, color: Colors.white, size: 16)),
                              ),
                            )
                          ],
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Show newly selected images
                    if (newImages.isNotEmpty) ...[
                      const Align(alignment: Alignment.centerLeft, child: Text("New Images:", style: TextStyle(fontSize: 12))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: newImages.map((file) => Stack(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: FutureBuilder<Uint8List>(
                                future: file.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) return Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover);
                                  return const SizedBox(width: 80, height: 80, child: Center(child: CircularProgressIndicator()));
                                }
                            )),
                            Positioned(
                              right: 0, top: 0,
                              child: GestureDetector(
                                onTap: () => setDialogState(() => newImages.remove(file)),
                                child: Container(color: Colors.black54, child: const Icon(Icons.close, color: Colors.white, size: 16)),
                              ),
                            )
                          ],
                        )).toList(),
                      ),
                    ],

                    TextButton.icon(
                      onPressed: () async {
                        final images = await _picker.pickMultiImage();
                        if (images.isNotEmpty) {
                          setDialogState(() => newImages.addAll(images));
                        }
                      },
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Images'),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isUpdating ? null : () async {
                    setDialogState(() => isUpdating = true);
                    try {
                      // 1. Delete removed images from storage
                      if (imagesToDelete.isNotEmpty) {
                        List<String> paths = imagesToDelete.map((url) => _getStoragePathFromUrl(url)).where((p) => p.isNotEmpty).toList();
                        if (paths.isNotEmpty) await _supabase.storage.from(_storageBucket).remove(paths);
                      }

                      // 2. Upload new images
                      List<String> uploadedUrls = [];
                      if (newImages.isNotEmpty) uploadedUrls = await _uploadImages(newImages);

                      // 3. Combine existing (not deleted) and newly uploaded urls
                      List<String> finalImageUrls = [...existingImages, ...uploadedUrls];

                      // 4. Update Database
                      await _supabase.from('comments').update({
                        'content': contentController.text.trim(),
                        'image_urls': finalImageUrls,
                      }).eq('id', comment['id']);

                      if (!mounted) return;
                      Navigator.pop(context);
                      _fetchComments();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment updated!')));
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
    final currentUserId = _supabase.auth.currentUser?.id;

    final List<String> postImages = widget.post.imageUrls ?? [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Post Details'),
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
                                  " • Posted by u/${widget.post.authorName} • ${_getTimeDisplay(widget.post.createdAt)}",
                                  style: TextStyle(fontSize: 12, color: secondaryTextColor, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(widget.post.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor, height: 1.3)),
                          const SizedBox(height: 14),
                          Text(widget.post.content, style: TextStyle(fontSize: 15, color: primaryTextColor, height: 1.5)),

                          if (postImages.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _FeedImageGallery(imageUrls: postImages),
                          ],
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
                                    Text('No comments yet.', textAlign: TextAlign.center, style: TextStyle(color: secondaryTextColor, fontSize: 13)),
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
                                final isOwner = comment['user_id'] == currentUserId;

                                final List<String> commentImages = List<String>.from(comment['image_urls'] ?? []);

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
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

                                          if (commentImages.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            _FeedImageGallery(imageUrls: commentImages),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isOwner)
                                      PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(Icons.more_vert, size: 18, color: secondaryTextColor),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEditCommentDialog(comment);
                                          } else if (value == 'delete') {
                                            _showDeleteCommentDialog(comment);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, size: 18, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Delete', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
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

            // BOTTOM INPUT AREA WITH IMAGE PREVIEWS
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(color: cardColor, border: Border(top: BorderSide(color: borderColor))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedImages.isNotEmpty) ...[
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: FutureBuilder<Uint8List>(
                                    future: _selectedImages[index].readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) return Image.memory(snapshot.data!, width: 50, height: 50, fit: BoxFit.cover);
                                      return const SizedBox(width: 50, height: 50, child: Center(child: CircularProgressIndicator()));
                                    },
                                  ),
                                ),
                                Positioned(
                                  right: 0, top: 0,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedImages.removeAt(index)),
                                    child: Container(color: Colors.black54, child: const Icon(Icons.close, color: Colors.white, size: 14)),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      IconButton(
                        onPressed: _pickImages,
                        icon: Icon(Icons.image_outlined, color: secondaryTextColor),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
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
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}