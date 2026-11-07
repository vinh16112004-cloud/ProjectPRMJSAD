import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled1/core/services/interaction_storage_service.dart';
import 'package:untitled1/models/article_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Reading History Operations & Filters', () {
    final article1 = ArticleModel(
      id: 'art-1',
      title: 'Tin tuc hom nay',
      summary: 'Tom tat hom nay',
      content: 'Noi dung chi tiet 1',
      categoryId: 'cat-1',
      thumbnailUrl: '',
      author: 'Tac gia A',
      status: 1,
      isHot: false,
      publishedAt: 1700000000,
    );

    final article2 = ArticleModel(
      id: 'art-2',
      title: 'Tin tuc thu hai',
      summary: 'Tom tat thu hai',
      content: 'Noi dung chi tiet 2',
      categoryId: 'cat-2',
      thumbnailUrl: '',
      author: 'Tac gia B',
      status: 1,
      isHot: true,
      publishedAt: 1700000000,
    );

    test('records reading history and retrieves list', () async {
      await InteractionStorageService.recordArticleRead(article1);
      await InteractionStorageService.recordArticleRead(article2);

      final list = await InteractionStorageService.getReadingHistory();
      expect(list.length, 2);
      expect(list.first['article_id'], 'art-2'); // Newest read is on top
      expect(list.last['article_id'], 'art-1');
    });

    test('deletes single item from reading history', () async {
      await InteractionStorageService.recordArticleRead(article1);
      await InteractionStorageService.recordArticleRead(article2);

      await InteractionStorageService.removeReadingHistoryItem('art-1');
      final list = await InteractionStorageService.getReadingHistory();
      expect(list.length, 1);
      expect(list.first['article_id'], 'art-2');
    });

    test('clears entire reading history', () async {
      await InteractionStorageService.recordArticleRead(article1);
      await InteractionStorageService.recordArticleRead(article2);

      await InteractionStorageService.clearReadingHistory();
      final list = await InteractionStorageService.getReadingHistory();
      expect(list, isEmpty);
    });

    test('correctly evaluates time filters', () {
      final now = DateTime.now();
      final todayTimestamp = now.millisecondsSinceEpoch;
      final yesterdayTimestamp = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final fourDaysAgoTimestamp = now.subtract(const Duration(days: 4)).millisecondsSinceEpoch;
      final tenDaysAgoTimestamp = now.subtract(const Duration(days: 10)).millisecondsSinceEpoch;

      bool matchesFilter(int readAt, String filter) {
        final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        final startOfYesterday = DateTime(now.year, now.month, now.day - 1).millisecondsSinceEpoch;
        final sevenDaysAgo = DateTime(now.year, now.month, now.day - 7).millisecondsSinceEpoch;

        switch (filter) {
          case 'Hôm nay':
            return readAt >= startOfToday;
          case 'Hôm qua':
            return readAt >= startOfYesterday && readAt < startOfToday;
          case '7 ngày qua':
            return readAt >= sevenDaysAgo;
          case 'Cũ hơn':
            return readAt < sevenDaysAgo;
          case 'Tất cả':
          default:
            return true;
        }
      }

      // Hôm nay
      expect(matchesFilter(todayTimestamp, 'Hôm nay'), isTrue);
      expect(matchesFilter(yesterdayTimestamp, 'Hôm nay'), isFalse);

      // Hôm qua
      expect(matchesFilter(yesterdayTimestamp, 'Hôm qua'), isTrue);
      expect(matchesFilter(todayTimestamp, 'Hôm qua'), isFalse);

      // 7 ngày qua
      expect(matchesFilter(fourDaysAgoTimestamp, '7 ngày qua'), isTrue);
      expect(matchesFilter(tenDaysAgoTimestamp, '7 ngày qua'), isFalse);

      // Cũ hơn
      expect(matchesFilter(tenDaysAgoTimestamp, 'Cũ hơn'), isTrue);
      expect(matchesFilter(fourDaysAgoTimestamp, 'Cũ hơn'), isFalse);
    });
  });
}
