
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'article_detail_view.dart';
import 'package:untitled1/models/article_model.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final controller = TextEditingController();
  List<ArticleModel> results = [];
  bool isLoading = false;
  bool hasSearched = false;

  Future<void> search() async {
    String key = controller.text.toLowerCase().trim();

    if (key.isEmpty) {
      setState(() {
        results = [];
        hasSearched = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      hasSearched = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('articles')
          .where('status', isEqualTo: 1)
          .get();

      final articles = snapshot.docs
          .map((doc) => ArticleModel.fromMap(doc.data(), doc.id))
          .where((article) =>
      article.title.toLowerCase().contains(key) ||
          article.summary.toLowerCase().contains(key))
          .toList();

      if (!mounted) return;

      setState(() {
        results = articles;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tìm kiếm: $e')),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Tìm kiếm bài viết...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => search(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: search,
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasSearched
          ? const Center(
        child: Text('Nhập từ khóa để tìm kiếm bài viết'),
      )
          : results.isEmpty
          ? const Center(
        child: Text('Không tìm thấy bài viết'),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final article = results[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),

              // Ảnh bài viết
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: article.thumbnailUrl.isNotEmpty
                    ? Image.network(
                  article.thumbnailUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) {
                    return const SizedBox(
                      width: 90,
                      height: 90,
                      child: Icon(
                        Icons.broken_image,
                        size: 35,
                      ),
                    );
                  },
                )
                    : const SizedBox(
                  width: 90,
                  height: 90,
                  child: Icon(
                    Icons.image,
                    size: 35,
                  ),
                ),
              ),

              // Tiêu đề và nội dung
              title: Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  article.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ArticleDetailView(article: article),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
