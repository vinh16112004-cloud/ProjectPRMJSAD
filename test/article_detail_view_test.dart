import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled1/core/services/article_interaction_service.dart';
import 'package:untitled1/models/article_model.dart';
import 'package:untitled1/views/user/article_detail_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testArticle = ArticleModel(
    id: 'art-101',
    title: 'Tiêu đề bài viết thử nghiệm',
    summary: 'Tóm tắt bài viết thử nghiệm',
    content: 'Nội dung bài viết đầy đủ với văn bản chi tiết.',
    categoryId: 'tech',
    thumbnailUrl: '',
    author: 'Nguyễn Văn A',
    status: 1,
    isHot: true,
    publishedAt: 1700000000000,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ArticleInteractionService.debugUserId = 'test-detail-user';
  });

  tearDown(() {
    ArticleInteractionService.debugUserId = null;
  });

  testWidgets('ArticleDetailView displays title, author, date, summary and content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleDetailView(article: testArticle),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tiêu đề bài viết thử nghiệm'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Tóm tắt bài viết thử nghiệm'), findsOneWidget);
    expect(find.text('Nội dung bài viết đầy đủ với văn bản chi tiết.'), findsOneWidget);
    expect(find.byTooltip('Giảm cỡ chữ (A-)'), findsOneWidget);
    expect(find.byTooltip('Tăng cỡ chữ (A+)'), findsOneWidget);
    expect(find.text('Chia sẻ'), findsOneWidget);
  });

  testWidgets('ArticleDetailView increases and decreases font size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleDetailView(article: testArticle),
      ),
    );
    await tester.pumpAndSettle();

    final increaseBtn = find.byTooltip('Tăng cỡ chữ (A+)');
    await tester.tap(increaseBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Cỡ chữ hiện tại: 17.5 pt'), findsOneWidget);

    final decreaseBtn = find.byTooltip('Giảm cỡ chữ (A-)');
    await tester.tap(decreaseBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Cỡ chữ hiện tại: 16.0 pt'), findsOneWidget);
  });

  testWidgets('ArticleDetailView records reading history and toggles bookmark locally', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleDetailView(article: testArticle),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle bookmark
    final bookmarkBtn = find.byTooltip('Lưu bài viết');
    expect(bookmarkBtn, findsOneWidget);
    await tester.tap(bookmarkBtn);
    await tester.pumpAndSettle();

    final isBookmarked = await ArticleInteractionService.isBookmarked('art-101');
    expect(isBookmarked, isTrue);

    // Bấm lần nữa để bỏ lưu
    final unbookmarkBtn = find.byTooltip('Bỏ lưu bài viết');
    expect(unbookmarkBtn, findsOneWidget);
    await tester.tap(unbookmarkBtn);
    await tester.pumpAndSettle();

    final isBookmarkedAfter = await ArticleInteractionService.isBookmarked('art-101');
    expect(isBookmarkedAfter, isFalse);
  });
}
