import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:untitled1/models/comment_model.dart';
import 'package:untitled1/repositories/comment_repository.dart';
import 'package:untitled1/viewmodels/comment_viewmodel.dart';

class MockCommentRepository extends Mock implements CommentRepository {}

void main() {
  group('CommentModel Tests', () {
    test('creates model and verifies properties', () {
      final comment = CommentModel(
        id: 'cmt-1',
        articleId: 'art-1',
        userId: 'user-1',
        userName: 'Nguyen Van A',
        userAvatar: 'https://example.com/avatar.jpg',
        content: 'Bai viet rat hay!',
        createdAt: 1700000000000,
        parentId: null,
        replyToUserName: null,
        likes: ['user-2', 'user-3'],
      );

      expect(comment.id, 'cmt-1');
      expect(comment.likeCount, 2);
      expect(comment.isLikedBy('user-2'), isTrue);
      expect(comment.isLikedBy('user-1'), isFalse);
    });

    test('serializes toMap and fromMap correctly including replies', () {
      final replyComment = CommentModel(
        id: 'cmt-2',
        articleId: 'art-1',
        userId: 'user-2',
        userName: 'Tran B',
        userAvatar: '',
        content: 'Minh cung dong quan diem',
        createdAt: 1700000005000,
        parentId: 'cmt-1',
        replyToUserName: 'Nguyen Van A',
        likes: ['user-1'],
      );

      final map = replyComment.toMap();
      expect(map['parent_id'], 'cmt-1');
      expect(map['reply_to_user_name'], 'Nguyen Van A');
      expect(map['likes'], ['user-1']);

      final restored = CommentModel.fromMap(map, 'cmt-2');
      expect(restored.id, 'cmt-2');
      expect(restored.parentId, 'cmt-1');
      expect(restored.replyToUserName, 'Nguyen Van A');
      expect(restored.likeCount, 1);
      expect(restored.isLikedBy('user-1'), isTrue);
    });
  });

  group('CommentViewModel Tests', () {
    late MockCommentRepository mockRepo;
    late CommentViewModel viewModel;

    setUp(() {
      mockRepo = MockCommentRepository();
      viewModel = CommentViewModel(mockRepo);
    });

    test('sendComment throws Exception when content is empty', () async {
      expect(
        () => viewModel.sendComment(
          articleId: 'art-1',
          userId: 'u1',
          userName: 'User',
          userAvatar: '',
          content: '   ',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('sendComment calls repository when valid', () async {
      when(() => mockRepo.addComment(
            articleId: any(named: 'articleId'),
            userId: any(named: 'userId'),
            userName: any(named: 'userName'),
            userAvatar: any(named: 'userAvatar'),
            content: any(named: 'content'),
            parentId: any(named: 'parentId'),
            replyToUserName: any(named: 'replyToUserName'),
          )).thenAnswer((_) async => CommentModel(
            id: 'cmt-new',
            articleId: 'art-1',
            userId: 'u1',
            userName: 'User',
            userAvatar: '',
            content: 'Nhan xet moi',
            createdAt: 1700000000,
          ));

      await viewModel.sendComment(
        articleId: 'art-1',
        userId: 'u1',
        userName: 'User',
        userAvatar: '',
        content: 'Nhan xet moi',
        parentId: 'cmt-parent',
        replyToUserName: 'ParentUser',
      );

      verify(() => mockRepo.addComment(
            articleId: 'art-1',
            userId: 'u1',
            userName: 'User',
            userAvatar: '',
            content: 'Nhan xet moi',
            parentId: 'cmt-parent',
            replyToUserName: 'ParentUser',
          )).called(1);
    });

    test('toggleReaction delegates to repository', () async {
      when(() => mockRepo.toggleReaction(
            commentId: any(named: 'commentId'),
            userId: any(named: 'userId'),
            currentIsLiked: any(named: 'currentIsLiked'),
          )).thenAnswer((_) async {});

      await viewModel.toggleReaction(
        commentId: 'cmt-1',
        userId: 'u1',
        currentIsLiked: false,
      );

      verify(() => mockRepo.toggleReaction(
            commentId: 'cmt-1',
            userId: 'u1',
            currentIsLiked: false,
          )).called(1);
    });

    test('deleteComment delegates to repository', () async {
      when(() => mockRepo.deleteComment(
            commentId: any(named: 'commentId'),
            articleId: any(named: 'articleId'),
          )).thenAnswer((_) async {});

      await viewModel.deleteComment(
        commentId: 'cmt-1',
        articleId: 'art-1',
      );

      verify(() => mockRepo.deleteComment(
            commentId: 'cmt-1',
            articleId: 'art-1',
          )).called(1);
    });
  });
}
