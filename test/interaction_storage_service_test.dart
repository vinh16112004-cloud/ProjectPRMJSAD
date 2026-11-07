import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled1/core/article_content_parser.dart';
import 'package:untitled1/core/services/interaction_storage_service.dart';
import 'package:untitled1/models/article_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ArticleContentParser Tests', () {
    test('converts basic HTML tags to Markdown', () {
      const html = '<p>Xin chao <b>the gioi</b>!</p><br/><h3>Tieu de con</h3>';
      final markdown = ArticleContentParser.parseToMarkdown(html);

      expect(markdown, contains('**the gioi**'));
      expect(markdown, contains('### Tieu de con'));
    });

    test('converts HTML image tags to Markdown image syntax', () {
      const html = '<p>Hinh anh:</p><img src="https://example.com/image.jpg" alt="Anh dep" />';
      final markdown = ArticleContentParser.parseToMarkdown(html);

      expect(markdown, contains('![](https://example.com/image.jpg)'));
    });

    test('converts HTML links and decodes entities', () {
      const html = '<a href="https://flutter.dev">Trang chu Flutter</a> &amp; &quot;Tin tuc&quot;';
      final markdown = ArticleContentParser.parseToMarkdown(html);

      expect(markdown, contains('[Trang chu Flutter](https://flutter.dev)'));
      expect(markdown, contains('& "Tin tuc"'));
    });
  });

  group('InteractionStorageService Tests', () {
    final sampleArticle = ArticleModel(
      id: 'art-1',
      title: 'Khai mac hoi nghi công nghe',
      summary: 'Tom tat bai viet cong nghe',
      content: 'Noi dung chi tiet bai viet cong nghe',
      categoryId: 'cat-tech',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      author: 'Nguyen Van A',
      status: 1,
      isHot: true,
      publishedAt: 1700000000000,
    );

    test('manages reading font size persistence', () async {
      final defaultSize = await InteractionStorageService.getArticleFontSize();
      expect(defaultSize, 16.0);

      await InteractionStorageService.saveArticleFontSize(18.5);
      final updatedSize = await InteractionStorageService.getArticleFontSize();
      expect(updatedSize, 18.5);
    });

    test('manages bookmark toggle and offline cache', () async {
      expect(await InteractionStorageService.isArticleBookmarked('art-1'), isFalse);

      final isSaved = await InteractionStorageService.toggleBookmark(sampleArticle);
      expect(isSaved, isTrue);
      expect(await InteractionStorageService.isArticleBookmarked('art-1'), isTrue);

      final bookmarks = await InteractionStorageService.getBookmarkedArticles();
      expect(bookmarks.length, 1);
      expect(bookmarks.first.id, 'art-1');
      expect(bookmarks.first.title, 'Khai mac hoi nghi công nghe');

      final isRemoved = await InteractionStorageService.toggleBookmark(sampleArticle);
      expect(isRemoved, isFalse);
      expect(await InteractionStorageService.isArticleBookmarked('art-1'), isFalse);
    });

    test('records reading history and clears history', () async {
      await InteractionStorageService.recordArticleRead(sampleArticle);

      final history = await InteractionStorageService.getReadingHistory();
      expect(history.length, 1);
      expect(history.first['article_id'], 'art-1');
      expect(history.first['title'], 'Khai mac hoi nghi công nghe');

      await InteractionStorageService.clearReadingHistory();
      final emptyHistory = await InteractionStorageService.getReadingHistory();
      expect(emptyHistory, isEmpty);
    });
  });
}
