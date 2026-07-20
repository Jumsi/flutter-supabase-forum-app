import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // Replaced dart:io with this for Web support
import '../data/post_model.dart';
import '../data/post_repository.dart';

class PostsProvider extends ChangeNotifier {
  final PostRepository _postRepository = PostRepository();

  List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _hasMore = true;
  String? _errorMessage;

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  final int _limit = 10;

  Future<void> refreshPosts() async {
    _isLoading = true;
    _errorMessage = null;
    _hasMore = true;
    _posts.clear();
    notifyListeners();
    try {
      final fetched = await _postRepository.fetchPosts(limit: _limit, offset: 0);
      _posts = fetched;
      if (fetched.length < _limit) { _hasMore = false; }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePosts() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();
    try {
      final fetched = await _postRepository.fetchPosts(limit: _limit, offset: _posts.length);
      if (fetched.length < _limit) { _hasMore = false; }
      _posts.addAll(fetched);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addNewPost({
    required String title,
    required String content,
    required List<XFile> imageFiles, // UPDATED: Now uses XFile to prevent Web crashes
    required String authorName,      // UPDATED: Accepts authorName directly from the UI
  }) async {
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      List<String> uploadedUrls = [];
      if (imageFiles.isNotEmpty) {
        uploadedUrls = await _postRepository.uploadImages(imageFiles);
      }
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? 'anonymous';

      // Removed the manual emailPrefix calculation since the UI handles the naming logic now
      final newPost = PostModel(
        id: '',
        title: title,
        content: content,
        authorName: authorName, // Uses the parameter directly
        userId: userId,
        imageUrls: uploadedUrls,
        commentsCount: 0,
      );

      await _postRepository.createPost(newPost);
      await refreshPosts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> removePost(String postId) async {
    try {
      await _postRepository.deletePost(postId);
      _posts.removeWhere((post) => post.id == postId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}