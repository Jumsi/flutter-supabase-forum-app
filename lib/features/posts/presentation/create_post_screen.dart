import 'dart:typed_data'; // Replaced dart:io with this for Uint8List
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isAnonymous = false;
  String _userNickname = 'user';
  List<XFile> _selectedImages = []; // Stores the selected images

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

  /// Opens gallery to pick multiple images
  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedImages = await _picker.pickMultiImage(
        imageQuality: 70, // Compresses image to save storage space and bandwidth
      );
      if (pickedImages.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedImages);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  /// Removes an image from the preview list before uploading
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Publishes the post with images
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
      List<String> uploadedUrls = [];

      // 1. Upload each selected image to Supabase Storage using bytes for Web support
      for (XFile image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final fileExt = image.name.split('.').last;
        // Create a unique file name
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final filePath = 'public/$fileName';

        await _supabase.storage.from('post_images').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt'),
        );

        // Get the public URL for the uploaded image
        final String publicUrl = _supabase.storage
            .from('post_images')
            .getPublicUrl(filePath);

        uploadedUrls.add(publicUrl);
      }

      // 2. Save the post to the database along with the image URLs
      await _supabase.from('posts').insert({
        'title': title,
        'content': content,
        'user_id': user?.id,
        'username': authorToSave,
        'image_urls': uploadedUrls, // Save the array of public URLs
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

            // Image Picker Button
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickImages,
                icon: Icon(Icons.add_photo_alternate, color: primaryColor),
                label: Text(
                  'Add Images',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Image Preview Grid
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true, // Needed because it's inside a SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List>(
                          future: _selectedImages[index].readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              );
                            }
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 24),

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