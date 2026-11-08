import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/article_model.dart';

class InteractionStorageService {
  static const String _keyLikedPrefix = 'liked_article_';
  static const String _keyBookmarks = 'saved_bookmarks_v1';
  static const String _keyReadingHistory = 'reading_history_v1';
  static const String _keyArticleFontSize = 'article_reading_font_size';

  // ===========================================================================
  // 1. CỠ CHỮ ĐỌC BÀI VIẾT (FONT SIZE)
  // ===========================================================================

  static Future<double> getArticleFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyArticleFontSize) ?? 16.0;
  }

  static Future<void> saveArticleFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyArticleFontSize, size);
  }

  // ===========================================================================
  // 2. YÊU THÍCH / LIKE BÀI VIẾT
  // ===========================================================================

  static Future<bool> isArticleLiked(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final localLiked = prefs.getBool('$_keyLikedPrefix$articleId') ?? false;
    return localLiked;
  }

  static Future<bool> toggleLike(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentStatus = prefs.getBool('$_keyLikedPrefix$articleId') ?? false;
    final newStatus = !currentStatus;

    await prefs.setBool('$_keyLikedPrefix$articleId', newStatus);

    // Cập nhật số lượt thích lên Firestore (nếu có kết nối mạng)
    try {
      final docRef = FirebaseFirestore.instance.collection('articles').doc(articleId);
      await docRef.update({
        'likes_count': FieldValue.increment(newStatus ? 1 : -1),
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userLikesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('likes')
            .doc(articleId);

        if (newStatus) {
          await userLikesRef.set({
            'article_id': articleId,
            'liked_at': FieldValue.serverTimestamp(),
          });
        } else {
          await userLikesRef.delete();
        }
      }
    } catch (_) {
      // Tiếp tục hoạt động offline ngay cả khi không có mạng
    }

    return newStatus;
  }

  static Future<int> getLikeCount(String articleId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('articles').doc(articleId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return (data['likes_count'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // ===========================================================================
  // 3. BOOKMARK / DANH SÁCH YÊU THÍCH (LƯU ĐỌC OFFLINE)
  // ===========================================================================

  static Future<bool> isArticleBookmarked(String articleId) async {
    final bookmarks = await getBookmarkedArticles();
    return bookmarks.any((item) => item.id == articleId);
  }

  static Future<bool> toggleBookmark(ArticleModel article) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getBookmarkedArticles();
    final index = list.indexWhere((item) => item.id == article.id);

    bool isSaved;
    if (index >= 0) {
      list.removeAt(index);
      isSaved = false;
    } else {
      list.insert(0, article);
      isSaved = true;
    }

    final rawJsonList = list.map((a) {
      final map = a.toMap();
      map['id'] = a.id;
      return jsonEncode(map);
    }).toList();

    await prefs.setStringList(_keyBookmarks, rawJsonList);

    // Đồng bộ Firestore nếu người dùng đã đăng nhập
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final bookmarkDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('bookmarks')
            .doc(article.id);

        if (isSaved) {
          final data = article.toMap();
          data['bookmarked_at'] = FieldValue.serverTimestamp();
          await bookmarkDoc.set(data);
        } else {
          await bookmarkDoc.delete();
        }
      }
    } catch (_) {}

    return isSaved;
  }

  static Future<List<ArticleModel>> getBookmarkedArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyBookmarks) ?? [];
    final List<ArticleModel> articles = [];

    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final id = map['id']?.toString() ?? '';
        articles.add(ArticleModel.fromMap(map, id));
      } catch (_) {}
    }
    return articles;
  }

  static Future<void> removeBookmark(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getBookmarkedArticles();
    list.removeWhere((item) => item.id == articleId);

    final rawJsonList = list.map((a) {
      final map = a.toMap();
      map['id'] = a.id;
      return jsonEncode(map);
    }).toList();

    await prefs.setStringList(_keyBookmarks, rawJsonList);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('bookmarks')
            .doc(articleId)
            .delete();
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 4. LỊCH SỬ ĐỌC BÀI (READING HISTORY)
  // ===========================================================================

  static Future<void> recordArticleRead(ArticleModel article) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyReadingHistory) ?? [];

    List<Map<String, dynamic>> history = [];
    for (final raw in rawList) {
      try {
        history.add(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Xóa lần đọc trước đó của bài viết nếu có để đưa lên đầu danh sách
    history.removeWhere((item) => item['article_id'] == article.id);

    final historyItem = {
      'article_id': article.id,
      'title': article.title,
      'summary': article.summary,
      'content': article.content,
      'author': article.author,
      'thumbnail_url': article.thumbnailUrl,
      'category_id': article.categoryId,
      'published_at': article.publishedAt,
      'status': article.status,
      'is_hot': article.isHot,
      'read_at': DateTime.now().millisecondsSinceEpoch,
    };

    history.insert(0, historyItem);

    // Giới hạn lưu trữ tối đa 100 bài đã đọc gần nhất
    if (history.length > 100) {
      history = history.sublist(0, 100);
    }

    final rawJsonList = history.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_keyReadingHistory, rawJsonList);

    // Đồng bộ Firestore nếu đăng nhập
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reading_history')
            .doc(article.id)
            .set({
          'article_id': article.id,
          'read_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyReadingHistory) ?? [];
    final List<Map<String, dynamic>> list = [];

    for (final raw in rawList) {
      try {
        list.add(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return list;
  }

  static Future<void> removeReadingHistoryItem(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getReadingHistory();
    list.removeWhere((item) => item['article_id'] == articleId);

    final rawJsonList = list.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_keyReadingHistory, rawJsonList);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reading_history')
            .doc(articleId)
            .delete();
      }
    } catch (_) {}
  }

  static Future<void> clearReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyReadingHistory);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reading_history')
            .get();
        for (final doc in query.docs) {
          await doc.reference.delete();
        }
      }
    } catch (_) {}
  }
}
