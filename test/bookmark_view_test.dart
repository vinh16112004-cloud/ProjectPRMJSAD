import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled1/core/services/article_interaction_service.dart';
import 'package:untitled1/models/article_model.dart';
import 'package:untitled1/views/user/bookmark_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ArticleInteractionService.debugUserId = null;
  });

  tearDown(() {
    ArticleInteractionService.debugUserId = null;
  });

  testWidgets('BookmarkView requires login when user is guest', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookmarkView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu đăng nhập'), findsOneWidget);
    expect(find.text('Đăng nhập ngay'), findsOneWidget);
  });

  testWidgets('BookmarkView shows empty state when logged in but has no saved articles', (tester) async {
    ArticleInteractionService.debugUserId = 'test-bookmark-user';

    await tester.pumpWidget(
      const MaterialApp(
        home: BookmarkView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tin đã lưu (Đọc Offline)'), findsOneWidget);
    expect(find.text('Chưa có bài viết nào được lưu'), findsOneWidget);
  });

  testWidgets('BookmarkView displays saved articles, filters by category, and unbookmarks', (tester) async {
    ArticleInteractionService.debugUserId = 'test-bookmark-user';

    final articleTech = ArticleModel(
      id: 'bm-tech-1',
      title: 'Bài báo Công nghệ đã lưu',
      summary: 'Tóm tắt tech',
      content: 'Nội dung chi tiết tech để đọc offline.',
      categoryId: 'CongNghe',
      thumbnailUrl: '',
      author: 'Nguyễn Văn Tech',
      status: 1,
      isHot: false,
      publishedAt: 1700000000000,
    );

    final articleSport = ArticleModel(
      id: 'bm-sport-1',
      title: 'Bài báo Thể thao đã lưu',
      summary: 'Tóm tắt thể thao',
      content: 'Nội dung thể thao để đọc offline.',
      categoryId: 'TheThao',
      thumbnailUrl: '',
      author: 'Lê Thể Thao',
      status: 1,
      isHot: true,
      publishedAt: 1700000000000,
    );

    await ArticleInteractionService.toggleBookmark(articleTech);
    await ArticleInteractionService.toggleBookmark(articleSport);

    await tester.pumpWidget(
      const MaterialApp(
        home: BookmarkView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bài báo Công nghệ đã lưu'), findsOneWidget);
    expect(find.text('Bài báo Thể thao đã lưu'), findsOneWidget);

    // Kiểm tra các chip phân loại
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('CongNghe (1)'), findsOneWidget);
    expect(find.text('TheThao (1)'), findsOneWidget);

    // Lọc theo CongNghe
    await tester.tap(find.text('CongNghe (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Bài báo Công nghệ đã lưu'), findsOneWidget);
    expect(find.text('Bài báo Thể thao đã lưu'), findsNothing);

    // Bấm lại Tất cả
    await tester.tap(find.text('Tất cả (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Bài báo Công nghệ đã lưu'), findsOneWidget);
    expect(find.text('Bài báo Thể thao đã lưu'), findsOneWidget);

    // Nút Bỏ lưu bài viết
    final unbookmarkButtons = find.byTooltip('Bỏ lưu bài viết');
    expect(unbookmarkButtons, findsNWidgets(2));

    await tester.tap(unbookmarkButtons.first);
    await tester.pumpAndSettle();

    final remaining = await ArticleInteractionService.getBookmarks();
    expect(remaining.length, 1);
  });
}
