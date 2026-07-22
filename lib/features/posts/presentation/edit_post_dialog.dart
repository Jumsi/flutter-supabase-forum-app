import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/post_model.dart';
import '../providers/posts_provider.dart';

class EditPostDialog extends StatefulWidget {
  final PostModel post;

  const EditPostDialog({super.key, required this.post});

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  // Track existing images that haven't been deleted
  late List<String> _existingImageUrls;

  // Track newly picked images to be uploaded
  final List<XFile> _newSelectedImages = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _contentController = TextEditingController(text: widget.post.content);
    _existingImageUrls = List.from(widget.post.imageUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedImages = await _picker.pickMultiImage(
        imageQuality: 70,
      );
      if (pickedImages.isNotEmpty) {
        setState(() {
          _newSelectedImages.addAll(pickedImages);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newSelectedImages.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content cannot be empty')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      List<String> finalImageUrls = List.from(_existingImageUrls);

      // 1. Upload any newly selected images first
      for (var image in _newSelectedImages) {
        final bytes = await image.readAsBytes();
        final fileExt = image.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

        await supabase.storage.from('post_images').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'image/$fileExt',
          ),
        );

        final String publicUrl = supabase.storage.from('post_images').getPublicUrl(fileName);
        finalImageUrls.add(publicUrl);
      }

      // 2. Update the post in the database
      await supabase.from('posts').update({
        'title': title,
        'content': content,
        'image_urls': finalImageUrls,
      }).eq('id', widget.post.id);

      // 3. Refresh provider data and close dialog
      if (mounted) {
        await context.read<PostsProvider>().refreshPosts();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating post: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.deepPurpleAccent;

    return AlertDialog(
      title: const Text('Edit Post'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Content'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickImages,
                  icon: Icon(Icons.add_photo_alternate, color: primaryColor),
                  label: Text('Add Images', style: TextStyle(color: primaryColor)),
                ),
              ),
              const SizedBox(height: 8),

              // Display Existing & New Images in a Grid
              if (_existingImageUrls.isNotEmpty || _newSelectedImages.isNotEmpty) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _existingImageUrls.length + _newSelectedImages.length,
                  itemBuilder: (context, index) {
                    bool isExisting = index < _existingImageUrls.length;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isExisting
                              ? Image.network(
                            _existingImageUrls[index],
                            fit: BoxFit.cover,
                          )
                              : FutureBuilder<Uint8List>(
                            future: _newSelectedImages[index - _existingImageUrls.length].readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(snapshot.data!, fit: BoxFit.cover);
                              }
                              return const Center(child: CircularProgressIndicator());
                            },
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              if (isExisting) {
                                _removeExistingImage(index);
                              } else {
                                _removeNewImage(index - _existingImageUrls.length);
                              }
                            },
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}