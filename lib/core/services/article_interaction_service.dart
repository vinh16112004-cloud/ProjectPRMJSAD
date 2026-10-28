import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/article_model.dart';
import '../../models/reading_history_model.dart';

class ArticleInteractionService {
  static const String _keyBookmarks = 'local_bookmarks';
  static const String _keyLikes = 'local_likes';
  static const String _keyFontSize = 'article_reading_font_size';

  // Biến hỗ trợ test môi trường không có Firebase
  @visibleForTesting
  static String? debugUserId;

  static bool get isUserLoggedIn {
    try {
      return _auth?.currentUser != null || debugUserId != null;
    } catch (_) {
      return debugUserId != null;
    }
  }

  static String _getUserHistoryKey(String uid) => 'local_reading_history_$uid';

  static FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // 1. CỠ CHỮ ĐỌC BÀI BÁO (FONT SIZE)
  // ==========================================
  static Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyFontSize) ?? 16.0;
  }

  static Future<void> saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, size);
  }

  // ==========================================
  // 2. GHI NHẬN LỊCH SỬ ĐỌC (CHỈ DÀNH CHO USER ĐÃ ĐĂNG NHẬP)
  // ==========================================
  static String? get _currentUserId => _auth?.currentUser?.uid ?? debugUserId;

  static Future<void> recordReadingHistory(ArticleModel article) async {
    final uid = _currentUserId;
    if (uid == null) {
      // Khách chưa đăng nhập -> Không lưu lịch sử đọc
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final historyKey = _getUserHistoryKey(uid);
      final historyList = prefs.getStringList(historyKey) ?? [];

      // Dữ liệu mục lịch sử
      final historyItem = {
        'id': article.id,
        'article_id': article.id,
        'title': article.title,
        'summary': article.summary,
        'content': article.content,
        'thumbnail_url': article.thumbnailUrl,
        'author': article.author,
        'category_id': article.categoryId,
        'read_at': DateTime.now().millisecondsSinceEpoch,
      };

      // Xóa mục cũ nếu trùng id rồi chèn lên đầu
      historyList.removeWhere((item) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          return data['id'] == article.id || data['article_id'] == article.id;
        } catch (_) {
          return false;
        }
      });
      historyList.insert(0, jsonEncode(historyItem));

      // Giữ tối đa 100 mục trong bộ nhớ cache của user này
      if (historyList.length > 100) {
        historyList.removeRange(100, historyList.length);
      }
      await prefs.setStringList(historyKey, historyList);

      // Nếu có Firebase, đồng bộ lên Firestore
      final firestore = _firestore;
      if (firestore != null) {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('reading_history')
            .doc(article.id)
            .set(historyItem);
      }
    } catch (_) {
      // Bỏ qua lỗi âm thầm để không ảnh hưởng trải nghiệm đọc
    }
  }

  static Future<List<ReadingHistoryModel>> getReadingHistory() async {
    final uid = _currentUserId;
    if (uid == null) {
      // Chưa đăng nhập -> Trả về danh sách rỗng
      return [];
    }

    final Map<String, ReadingHistoryModel> historyMap = {};

    // 1. Đọc từ local cache của user này (SharedPreferences)
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyKey = _getUserHistoryKey(uid);
      final historyList = prefs.getStringList(historyKey) ?? [];
      for (final item in historyList) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          final model = ReadingHistoryModel.fromMap(data, data['id'] ?? data['article_id'] ?? '');
          historyMap[model.articleId] = model;
        } catch (_) {}
      }
    } catch (_) {}

    // 2. Nếu có Firebase, đọc/đồng bộ thêm từ Firestore của user này
    try {
      final firestore = _firestore;
      if (firestore != null) {
        final snapshot = await firestore
            .collection('users')
            .doc(uid)
            .collection('reading_history')
            .orderBy('read_at', descending: true)
            .get();

        for (final doc in snapshot.docs) {
          final model = ReadingHistoryModel.fromMap(doc.data(), doc.id);
          if (!historyMap.containsKey(model.articleId) ||
              model.readAt > (historyMap[model.articleId]?.readAt ?? 0)) {
            historyMap[model.articleId] = model;
          }
        }
      }
    } catch (_) {}

    final result = historyMap.values.toList();
    result.sort((a, b) => b.readAt.compareTo(a.readAt));
    return result;
  }

  static Future<void> deleteHistoryItem(String articleId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    // 1. Xóa trong Local
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyKey = _getUserHistoryKey(uid);
      final historyList = prefs.getStringList(historyKey) ?? [];
      historyList.removeWhere((item) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          return data['id'] == articleId || data['article_id'] == articleId;
        } catch (_) {
          return false;
        }
      });
      await prefs.setStringList(historyKey, historyList);
    } catch (_) {}

    // 2. Xóa trên Firestore
    try {
      final firestore = _firestore;
      if (firestore != null) {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('reading_history')
            .doc(articleId)
            .delete();
      }
    } catch (_) {}
  }

  static Future<void> clearAllHistory() async {
    final uid = _currentUserId;
    if (uid == null) return;

    // 1. Xóa trong Local
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyKey = _getUserHistoryKey(uid);
      await prefs.remove(historyKey);
    } catch (_) {}

    // 2. Xóa trên Firestore
    try {
      final firestore = _firestore;
      if (firestore != null) {
        final collectionRef = firestore
            .collection('users')
            .doc(uid)
            .collection('reading_history');
        final snapshot = await collectionRef.get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }
    } catch (_) {}
  }

  // ==========================================
  // 3. YÊU THÍCH / BOOKMARK (HỖ TRỢ OFFLINE)
  // ==========================================
  static String _getUserBookmarkKey(String? uid) => uid != null ? 'local_bookmarks_$uid' : _keyBookmarks;

  static Future<bool> isBookmarked(String articleId) async {
    try {
      final user = _auth?.currentUser;
      final firestore = _firestore;
      if (user != null && firestore != null) {
        final doc = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('bookmarks')
            .doc(articleId)
            .get();
        if (doc.exists) return true;
      }

      // Kiểm tra trong local cache
      final prefs = await SharedPreferences.getInstance();
      final uid = _currentUserId;
      final bookmarks = prefs.getStringList(_getUserBookmarkKey(uid)) ??
          prefs.getStringList(_keyBookmarks) ??
          [];
      return bookmarks.any((item) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          return data['id'] == articleId;
        } catch (_) {
          return false;
        }
      });
    } catch (_) {
      return false;
    }
  }

  static Future<List<ArticleModel>> getBookmarks() async {
    final uid = _currentUserId;
    final Map<String, ArticleModel> bookmarkMap = {};
    final prefs = await SharedPreferences.getInstance();

    // 1. Đọc từ Local cache
    try {
      final key = _getUserBookmarkKey(uid);
      final list = prefs.getStringList(key) ?? prefs.getStringList(_keyBookmarks) ?? [];
      for (final item in list) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          final docId = data['id'] ?? '';
          final article = ArticleModel.fromMap(data, docId);
          bookmarkMap[article.id] = article;
        } catch (_) {}
      }
    } catch (_) {}

    // 2. Nếu có Firebase & đã đăng nhập, đọc thêm từ Firestore
    try {
      final user = _auth?.currentUser;
      final firestore = _firestore;
      if (user != null && firestore != null) {
        final snapshot = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('bookmarks')
            .get();

        for (final doc in snapshot.docs) {
          final article = ArticleModel.fromMap(doc.data(), doc.id);
          bookmarkMap[article.id] = article;
        }
      }
    } catch (_) {}

    return bookmarkMap.values.toList();
  }

  static Future<void> removeBookmark(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _currentUserId;
    final user = _auth?.currentUser;
    final firestore = _firestore;

    // 1. Xóa trong local
    for (final key in [_getUserBookmarkKey(uid), _keyBookmarks]) {
      try {
        final list = prefs.getStringList(key) ?? [];
        list.removeWhere((item) {
          try {
            final data = jsonDecode(item) as Map<String, dynamic>;
            return data['id'] == articleId;
          } catch (_) {
            return false;
          }
        });
        await prefs.setStringList(key, list);
      } catch (_) {}
    }

    // 2. Xóa trên Firestore
    if (user != null && firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('bookmarks')
            .doc(articleId)
            .delete();
      } catch (_) {}
    }
  }

  static Future<bool> toggleBookmark(ArticleModel article) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _currentUserId;
    final bookmarkKey = _getUserBookmarkKey(uid);
    final bookmarks = prefs.getStringList(bookmarkKey) ?? prefs.getStringList(_keyBookmarks) ?? [];
    final user = _auth?.currentUser;
    final firestore = _firestore;

    bool currentlySaved = false;
    int existingIndex = -1;

    for (int i = 0; i < bookmarks.length; i++) {
      try {
        final data = jsonDecode(bookmarks[i]) as Map<String, dynamic>;
        if (data['id'] == article.id) {
          currentlySaved = true;
          existingIndex = i;
          break;
        }
      } catch (_) {}
    }

    final newStatus = !currentlySaved;

    if (newStatus) {
      // Thêm bài viết đầy đủ vào Local cache để đọc offline
      final articleMap = article.toMap();
      articleMap['id'] = article.id;
      articleMap['saved_at'] = DateTime.now().millisecondsSinceEpoch;
      bookmarks.insert(0, jsonEncode(articleMap));

      if (user != null && firestore != null) {
        try {
          await firestore
              .collection('users')
              .doc(user.uid)
              .collection('bookmarks')
              .doc(article.id)
              .set(articleMap);
        } catch (_) {}
      }
    } else {
      // Xóa khỏi Bookmark
      if (existingIndex >= 0) {
        bookmarks.removeAt(existingIndex);
      }
      if (user != null && firestore != null) {
        try {
          await firestore
              .collection('users')
              .doc(user.uid)
              .collection('bookmarks')
              .doc(article.id)
              .delete();
        } catch (_) {}
      }
    }

    await prefs.setStringList(bookmarkKey, bookmarks);
    return newStatus;
  }

  // ==========================================
  // 4. LƯỢT THÍCH (LIKE / UNLIKE)
  // ==========================================
  static Future<bool> isLiked(String articleId) async {
    try {
      final user = _auth?.currentUser;
      final firestore = _firestore;
      if (user != null && firestore != null) {
        final doc = await firestore
            .collection('articles')
            .doc(articleId)
            .collection('likes')
            .doc(user.uid)
            .get();
        if (doc.exists) return true;
      }

      // Check local fallback
      final prefs = await SharedPreferences.getInstance();
      final likes = prefs.getStringList(_keyLikes) ?? [];
      return likes.contains(articleId);
    } catch (_) {
      return false;
    }
  }

  static Stream<int> getLikeCountStream(String articleId) {
    try {
      final firestore = _firestore;
      if (firestore != null) {
        return firestore
            .collection('articles')
            .doc(articleId)
            .snapshots()
            .map((doc) {
              if (!doc.exists) return 0;
              final data = doc.data();
              return (data?['like_count'] as num?)?.toInt() ?? 0;
            });
      }
    } catch (_) {}
    return const Stream.empty();
  }

  static Future<bool> toggleLike(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final likes = prefs.getStringList(_keyLikes) ?? [];
    final user = _auth?.currentUser;
    final firestore = _firestore;

    final currentlyLiked = likes.contains(articleId);
    final newStatus = !currentlyLiked;

    if (newStatus) {
      likes.add(articleId);
    } else {
      likes.remove(articleId);
    }
    await prefs.setStringList(_keyLikes, likes);

    if (firestore != null) {
      try {
        final articleRef = firestore.collection('articles').doc(articleId);
        final incrementValue = newStatus ? 1 : -1;

        await articleRef.update({
          'like_count': FieldValue.increment(incrementValue),
        });

        if (user != null) {
          final likeDoc = articleRef.collection('likes').doc(user.uid);
          if (newStatus) {
            await likeDoc.set({
              'user_id': user.uid,
              'liked_at': FieldValue.serverTimestamp(),
            });
          } else {
            await likeDoc.delete();
          }
        }
      } catch (_) {
        // Nếu không update được Firestore (offline), local vẫn lưu trạng thái
      }
    }

    return newStatus;
  }
}
