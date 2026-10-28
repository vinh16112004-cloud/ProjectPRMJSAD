import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled1/core/services/article_interaction_service.dart';
import 'package:untitled1/models/article_model.dart';
import 'package:untitled1/views/user/reading_history_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ArticleInteractionService.debugUserId = null;
  });

  tearDown(() {
    ArticleInteractionService.debugUserId = null;
  });

  testWidgets('ReadingHistoryView requires login when user is guest', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingHistoryView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu đăng nhập'), findsOneWidget);
    expect(find.text('Đăng nhập ngay'), findsOneWidget);
  });

  testWidgets('ReadingHistoryView shows empty state when logged in but has no history', (tester) async {
    ArticleInteractionService.debugUserId = 'user-test-123';

    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingHistoryView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử đọc báo'), findsOneWidget);
    expect(find.text('Bạn chưa có lịch sử đọc báo nào'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Hôm qua'), findsOneWidget);
  });

  testWidgets('ReadingHistoryView displays recorded articles and deletes single item for logged-in user', (tester) async {
    ArticleInteractionService.debugUserId = 'user-test-123';

    final article1 = ArticleModel(
      id: 'history-1',
      title: 'Bài báo lịch sử số 1',
      summary: 'Tóm tắt bài 1',
      content: 'Nội dung bài 1',
      categoryId: 'news',
      thumbnailUrl: '',
      author: 'Tác giả 1',
      status: 1,
      isHot: false,
      publishedAt: 1700000000000,
    );

    final article2 = ArticleModel(
      id: 'history-2',
      title: 'Bài báo lịch sử số 2',
      summary: 'Tóm tắt bài 2',
      content: 'Nội dung bài 2',
      categoryId: 'sport',
      thumbnailUrl: '',
      author: 'Tác giả 2',
      status: 1,
      isHot: false,
      publishedAt: 1700000000000,
    );

    await ArticleInteractionService.recordReadingHistory(article1);
    await ArticleInteractionService.recordReadingHistory(article2);

    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingHistoryView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bài báo lịch sử số 1'), findsOneWidget);
    expect(find.text('Bài báo lịch sử số 2'), findsOneWidget);

    // Xóa bài báo số 1
    final deleteButtons = find.byTooltip('Xóa khỏi lịch sử');
    expect(deleteButtons, findsNWidgets(2));

    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    final remaining = await ArticleInteractionService.getReadingHistory();
    expect(remaining.length, 1);
  });

  testWidgets('ReadingHistoryView clears all history on confirm', (tester) async {
    ArticleInteractionService.debugUserId = 'user-test-123';

    final article = ArticleModel(
      id: 'history-3',
      title: 'Bài báo chuẩn bị xóa hết',
      summary: 'Tóm tắt',
      content: 'Nội dung',
      categoryId: 'tech',
      thumbnailUrl: '',
      author: 'Tác giả 3',
      status: 1,
      isHot: false,
      publishedAt: 1700000000000,
    );

    await ArticleInteractionService.recordReadingHistory(article);

    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingHistoryView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bài báo chuẩn bị xóa hết'), findsOneWidget);

    final clearAllBtn = find.byTooltip('Xóa toàn bộ lịch sử');
    expect(clearAllBtn, findsOneWidget);
    await tester.tap(clearAllBtn);
    await tester.pumpAndSettle();

    expect(find.text('Xóa toàn bộ lịch sử?'), findsOneWidget);

    final confirmBtn = find.text('Xóa tất cả');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.text('Bạn chưa có lịch sử đọc báo nào'), findsOneWidget);
    final history = await ArticleInteractionService.getReadingHistory();
    expect(history.isEmpty, isTrue);
  });
}
