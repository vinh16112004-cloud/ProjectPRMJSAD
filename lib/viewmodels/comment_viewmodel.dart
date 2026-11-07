import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment_model.dart';
import '../repositories/comment_repository.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository();
});

final articleCommentsStreamProvider =
    StreamProvider.family<List<CommentModel>, String>((ref, articleId) {
  final repository = ref.watch(commentRepositoryProvider);
  return repository.getCommentsForArticle(articleId);
});

final commentViewModelProvider = Provider<CommentViewModel>((ref) {
  final repository = ref.watch(commentRepositoryProvider);
  return CommentViewModel(repository);
});

class CommentViewModel {
  final CommentRepository _repository;

  CommentViewModel(this._repository);

  Future<void> sendComment({
    required String articleId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String content,
    String? parentId,
    String? replyToUserName,
  }) async {
    if (content.trim().isEmpty) {
      throw Exception('Nội dung bình luận không được để trống.');
    }

    await _repository.addComment(
      articleId: articleId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: content,
      parentId: parentId,
      replyToUserName: replyToUserName,
    );
  }

  Future<void> toggleReaction({
    required String commentId,
    required String userId,
    required bool currentIsLiked,
  }) async {
    await _repository.toggleReaction(
      commentId: commentId,
      userId: userId,
      currentIsLiked: currentIsLiked,
    );
  }

  Future<void> deleteComment({
    required String commentId,
    required String articleId,
  }) async {
    await _repository.deleteComment(
      commentId: commentId,
      articleId: articleId,
    );
  }
}
