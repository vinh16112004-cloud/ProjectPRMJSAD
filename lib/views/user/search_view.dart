import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  Future<void> _performSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('articles')
          .where('status', isEqualTo: 1)
          .orderBy('published_at', descending: true)
          .get();

      // Lọc từ khóa theo tiêu đề hoặc tóm tắt
      final results = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final title = (data['title'] ?? '').toString().toLowerCase();
        final summary = (data['summary'] ?? '').toString().toLowerCase();
        final key = keyword.toLowerCase();
        return title.contains(key) || summary.contains(key);
      }).toList();

      setState(() => _searchResults = results);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onSubmitted: _performSearch,
          decoration: const InputDecoration(
            hintText: 'Nhập từ khóa tìm kiếm bài viết...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Không tìm thấy bài viết phù hợp', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final item = _searchResults[index].data() as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(item['summary'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          );
        },
      ),
    );
  }
}