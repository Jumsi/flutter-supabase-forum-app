import 'package:flutter/material.dart';
import 'dart:io';
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

  // Fetch initial batch of posts or refresh the feed
  Future<void> refreshPosts() async {
    _isLoading = true;
    _errorMessage = null;
    _hasMore = true;
    _posts.clear();
    notifyListeners();

    try {
      final fetched = await _postRepository.fetchPosts(limit: _limit, offset: 0);
      _posts = fetched;
      if (fetched.length < _limit) {
        _hasMore = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load the next page of posts for pagination
  Future<void> loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final fetched = await _postRepository.fetchPosts(
        limit: _limit,
        offset: _posts.length,
      );

      if (fetched.length < _limit) {
        _hasMore = false;
      }
      _posts.addAll(fetched);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Handle uploading images and saving the text content as a new post
  Future<bool> addNewPost({
    required String title,
    required String content,
    required List<File> imageFiles,
  }) async {
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Upload files to Storage if any images are selected
      List<String> uploadedUrls = [];
      if (imageFiles.isNotEmpty) {
        uploadedUrls = await _postRepository.uploadImages(imageFiles);
      }

      // 2. Create the post model instance (id and user_id handled by Supabase)
      final newPost = PostModel(
        id: '',
        userId: '',
        title: title,
        content: content,
        imageUrls: uploadedUrls,
        createdAt: DateTime.now(),
      );

      // 3. Save details to database table
      await _postRepository.createPost(newPost);

      // 4. Refresh the local list automatically
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

  // Remove a post from the database and local memory
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