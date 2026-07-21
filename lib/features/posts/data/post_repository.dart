import 'package:image_picker/image_picker.dart'; // Replaced dart:io with this for Web compatibility
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_model.dart';

class PostRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch posts ordered by newest first, with simple limit/offset pagination
  Future<List<PostModel>> fetchPosts({required int limit, required int offset}) async {
    final response = await _supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) => PostModel.fromJson(json)).toList();
  }

  // Create a new post row in the database
  Future<void> createPost(PostModel post) async {
    await _supabase.from('posts').insert(post.toJson());
  }

  // Delete a post row by its ID
  Future<void> deletePost(String postId) async {
    await _supabase.from('posts').delete().eq('id', postId);
  }

  // Upload multiple image files to Supabase Storage using bytes (Web Safe) and return their public URLs
  Future<List<String>> uploadImages(List<XFile> images) async {
    List<String> imageUrls = [];

    for (var image in images) {
      // 1. Read file as bytes to prevent dart:io crashes on Web/GitHub Pages
      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      // 2. Upload file bytes to the 'post_images' storage bucket using uploadBinary
      await _supabase.storage.from('post_images').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: 'image/$fileExt',
        ),
      );

      // 3. Extract public web link from 'post_images'
      final String publicUrl = _supabase.storage.from('post_images').getPublicUrl(fileName);
      imageUrls.add(publicUrl);
    }

    return imageUrls;
  }
}