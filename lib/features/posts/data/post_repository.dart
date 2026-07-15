import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
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

  // Upload multiple image files to Supabase Storage and return their public URLs
  Future<List<String>> uploadImages(List<File> images) async {
    List<String> imageUrls = [];

    for (var image in images) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';

      // Upload file to the 'posts' bucket
      await _supabase.storage.from('posts').upload(
        fileName,
        image,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // Extract public web link
      final String publicUrl = _supabase.storage.from('posts').getPublicUrl(fileName);
      imageUrls.add(publicUrl);
    }

    return imageUrls;
  }
}