import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article_model.dart';
import '../models/category_model.dart';
import '../repositories/article_repository.dart';

// Khởi tạo Repository Provider
final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  return ArticleRepository();
});

final categoryListStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  return FirebaseFirestore.instance.collection('categories').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) {
      return CategoryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  });
});

// Stream Provider để lắng nghe dữ liệu bài báo từ Firestore
final articleStreamProvider = StreamProvider<List<ArticleModel>>((ref) {
  final repository = ref.watch(articleRepositoryProvider);
  return repository.getArticles();
});

// StateNotifier để quản lý logic lọc, tìm kiếm và thao tác CRUD bài báo
class ArticleControllerNotifier extends StateNotifier<AsyncValue<void>> {
  final ArticleRepository _repository;

  ArticleControllerNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> addArticle(ArticleModel article) async {
    state = const AsyncValue.loading();
    try {
      await _repository.addArticle(article);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateArticle(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateArticle(id, data);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteArticle(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteArticle(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final articleControllerProvider = StateNotifierProvider<ArticleControllerNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(articleRepositoryProvider);
  return ArticleControllerNotifier(repository);
});