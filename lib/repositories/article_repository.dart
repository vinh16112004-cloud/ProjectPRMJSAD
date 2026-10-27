import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/article_model.dart';

class ArticleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'articles';

  // Lấy stream danh sách bài báo realtime từ Firestore
  Stream<List<ArticleModel>> getArticles() {
    return _firestore.collection(collectionName).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ArticleModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Thêm bài báo mới (Lưu nháp hoặc Xuất bản)
  Future<void> addArticle(ArticleModel article) async {
    await _firestore.collection(collectionName).add(article.toMap());
  }

  // Cập nhật bài báo
  Future<void> updateArticle(String id, Map<String, dynamic> updatedData) async {
    await _firestore.collection(collectionName).doc(id).update(updatedData);
  }

  // Xóa bài báo
  Future<void> deleteArticle(String id) async {
    await _firestore.collection(collectionName).doc(id).delete();
  }
}