import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/core/services/comment_service.dart';
import 'package:untitled1/models/comment_model.dart';
import 'package:untitled1/views/user/widgets/article_comments_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CommentService.mockComments.clear();
    CommentService.debugUserId = 'user-test-id';
    CommentService.debugUserName = 'Người dùng test';
  });

  tearDown(() {
    CommentService.mockComments.clear();
    CommentService.debugUserId = null;
    CommentService.debugUserName = null;
  });

  test('CommentModel correctly parses fromMap and toMap', () {
    final comment = CommentModel(
      id: 'cmt-1',
      articleId: 'art-1',
      userId: 'user-1',
      userName: 'Nguyễn Văn B',
      userAvatar: 'https://example.com/avatar.jpg',
      content: 'Bài viết rất hay!',
      createdAt: 1700000000000,
      parentId: null,
      replyToUserName: null,
      likes: ['user-2'],
    );

    final map = comment.toMap();
    expect(map['article_id'], 'art-1');
    expect(map['content'], 'Bài viết rất hay!');
    expect(map['likes'], ['user-2']);

    final parsed = CommentModel.fromMap(map, 'cmt-1');
    expect(parsed.id, 'cmt-1');
    expect(parsed.userName, 'Nguyễn Văn B');
    expect(parsed.likes.length, 1);
  });

  testWidgets('ArticleCommentsSection displays empty state when there are no comments', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArticleCommentsSection(articleId: 'test-art-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bình luận (0)'), findsOneWidget);
    expect(find.text('Chưa có bình luận nào.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('ArticleCommentsSection displays comments, replies, and like interaction', (tester) async {
    final rootComment = CommentModel(
      id: 'root-1',
      articleId: 'test-art-1',
      userId: 'user-author-1',
      userName: 'Trần Văn C',
      userAvatar: '',
      content: 'Phân tích rất sâu sắc.',
      createdAt: DateTime.now().millisecondsSinceEpoch - 60000,
      likes: ['another-user'],
    );

    final replyComment = CommentModel(
      id: 'reply-1',
      articleId: 'test-art-1',
      userId: 'user-author-2',
      userName: 'Lê Thị D',
      userAvatar: '',
      content: 'Đồng ý với ý kiến của bạn!',
      createdAt: DateTime.now().millisecondsSinceEpoch - 30000,
      parentId: 'root-1',
      replyToUserName: 'Trần Văn C',
      likes: [],
    );

    CommentService.mockComments.addAll([rootComment, replyComment]);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArticleCommentsSection(articleId: 'test-art-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kiểm tra hiển thị tổng số comment (1 gốc + 1 trả lời = 2)
    expect(find.text('Bình luận (2)'), findsOneWidget);
    expect(find.text('Trần Văn C'), findsOneWidget);
    expect(find.text('Phân tích rất sâu sắc.'), findsOneWidget);
    expect(find.text('Lê Thị D'), findsOneWidget);
    expect(find.text('Đồng ý với ý kiến của bạn!'), findsOneWidget);
    expect(find.text('@Trần Văn C'), findsOneWidget);

    // Kiểm tra nút Reply
    final replyButtons = find.text('Trả lời');
    expect(replyButtons, findsNWidgets(2));

    await tester.tap(replyButtons.first);
    await tester.pumpAndSettle();

    // Khi bấm trả lời, banner @Trần Văn C hiển thị trên ô nhập
    expect(find.text('Đang trả lời @Trần Văn C'), findsOneWidget);

    // Bấm hủy trả lời
    final closeReplyBtn = find.byIcon(Icons.close);
    await tester.tap(closeReplyBtn);
    await tester.pumpAndSettle();
    expect(find.text('Đang trả lời @Trần Văn C'), findsNothing);
  });

  testWidgets('ArticleCommentsSection sends new comment via TextField', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArticleCommentsSection(articleId: 'test-art-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inputField = find.byType(TextField);
    await tester.enterText(inputField, 'Bình luận mới từ unit test');
    await tester.pump();

    final sendBtn = find.byIcon(Icons.send_rounded);
    await tester.tap(sendBtn);
    await tester.pumpAndSettle();

    expect(CommentService.mockComments.isNotEmpty, isTrue);
    expect(CommentService.mockComments.first.content, 'Bình luận mới từ unit test');
  });
}
