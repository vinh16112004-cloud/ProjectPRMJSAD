import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled1/core/services/interaction_storage_service.dart';
import 'package:untitled1/models/article_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bookmarks / Saved Articles Tests', () {
    final techArticle = ArticleModel(
      id: 'art-tech-1',
      title: 'Ra mat tri tue nhan tao moi',
      summary: 'Cong nghe dot pha nam 2026',
      content: 'Noi dung chi tiet ve AI',
      categoryId: 'cat-tech',
      thumbnailUrl: '',
      author: 'Chuyen gia Tech',
      status: 1,
      isHot: true,
      publishedAt: 1700000000,
    );

    final sportsArticle = ArticleModel(
      id: 'art-sport-1',
      title: 'Ket qua tran chung ket bong da',
      summary: 'Doi tuyen vo dich thuyet phuc',
      content: 'Noi dung chi tiet the thao',
      categoryId: 'cat-sports',
      thumbnailUrl: '',
      author: 'Phong vien The Thao',
      status: 1,
      isHot: false,
      publishedAt: 1700000000,
    );

    test('adds and retrieves bookmarked articles for offline reading', () async {
      await InteractionStorageService.toggleBookmark(techArticle);
      await InteractionStorageService.toggleBookmark(sportsArticle);

      final bookmarks = await InteractionStorageService.getBookmarkedArticles();
      expect(bookmarks.length, 2);
      expect(bookmarks.any((a) => a.id == 'art-tech-1'), isTrue);
      expect(bookmarks.any((a) => a.id == 'art-sport-1'), isTrue);

      // Verify content is preserved for offline reading
      final savedTech = bookmarks.firstWhere((a) => a.id == 'art-tech-1');
      expect(savedTech.content, 'Noi dung chi tiet ve AI');
    });

    test('filters bookmarked articles by category', () async {
      await InteractionStorageService.toggleBookmark(techArticle);
      await InteractionStorageService.toggleBookmark(sportsArticle);

      final bookmarks = await InteractionStorageService.getBookmarkedArticles();

      final techFiltered = bookmarks.where((a) => a.categoryId == 'cat-tech').toList();
      expect(techFiltered.length, 1);
      expect(techFiltered.first.title, contains('tri tue nhan tao'));

      final sportsFiltered = bookmarks.where((a) => a.categoryId == 'cat-sports').toList();
      expect(sportsFiltered.length, 1);
      expect(sportsFiltered.first.title, contains('bong da'));
    });

    test('searches bookmarked articles by keyword in title and summary', () async {
      await InteractionStorageService.toggleBookmark(techArticle);
      await InteractionStorageService.toggleBookmark(sportsArticle);

      final bookmarks = await InteractionStorageService.getBookmarkedArticles();

      const query = 'bong da';
      final searchResults = bookmarks.where((a) =>
          a.title.toLowerCase().contains(query.toLowerCase()) ||
          a.summary.toLowerCase().contains(query.toLowerCase())).toList();

      expect(searchResults.length, 1);
      expect(searchResults.first.id, 'art-sport-1');
    });

    test('removes bookmark and allows restoration (undo)', () async {
      await InteractionStorageService.toggleBookmark(techArticle);
      expect(await InteractionStorageService.isArticleBookmarked('art-tech-1'), isTrue);

      await InteractionStorageService.removeBookmark('art-tech-1');
      expect(await InteractionStorageService.isArticleBookmarked('art-tech-1'), isFalse);

      // Undo: re-save
      await InteractionStorageService.toggleBookmark(techArticle);
      expect(await InteractionStorageService.isArticleBookmarked('art-tech-1'), isTrue);
    });
  });
}
