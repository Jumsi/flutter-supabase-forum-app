import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app/features/auth/presentation/login_screen.dart';
import 'package:flutter_app/features/auth/presentation/register_screen.dart';
import 'package:flutter_app/features/posts/presentation/posts_feed_screen.dart';
import 'package:flutter_app/features/posts/presentation/create_post_screen.dart';
import 'package:flutter_app/features/posts/presentation/post_detail_screen.dart';
import 'package:flutter_app/features/posts/data/post_model.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    // 💡 Listens to Supabase Auth state changes (login, logout, token refresh)
    refreshListenable: _AuthStateNotifier(),
    redirect: (context, state) {
      final bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;

      final goingToProtectedArea = state.uri.toString().startsWith('/create-post') ||
          state.uri.toString().startsWith('/edit-post');

      final goingToAuthPage = state.uri.toString() == '/login' ||
          state.uri.toString() == '/register';

      if (!isLoggedIn && goingToProtectedArea) {
        return '/login';
      }

      if (isLoggedIn && goingToAuthPage) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PostsFeedScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/create-post',
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/post-detail',
        builder: (context, state) {
          final post = state.extra as PostModel;
          return PostDetailScreen(post: post);
        },
      ),
    ],
  );
}

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }
}