import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:untitled1/viewmodels/auth_viewmodel.dart';
import 'search_view.dart';
import 'settings_view.dart';
import 'feedback_view.dart';

class UserHomeView extends ConsumerStatefulWidget {
  const UserHomeView({super.key});

  @override
  ConsumerState<UserHomeView> createState() => _UserHomeViewState();
}

class _UserHomeViewState extends ConsumerState<UserHomeView> {
  String _selectedCategory = 'ALL';

  final List<Map<String, String>> _categories = [
    {'id': 'ALL', 'name': 'Khám phá'},
    {'id': 'thoisu', 'name': 'Thời sự'},
    {'id': 'congnghe', 'name': 'Công nghệ'},
    {'id': 'thegioi', 'name': 'Thế giới'},
    {'id': 'giaitri', 'name': 'Giải trí'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Báo Mới 24h - Dành cho bạn',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        // === THÊM CÁC NÚT VÀO ĐÂY (PHẦN ACTIONS) ===
        actions: [
          // Nút Tìm kiếm
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            tooltip: 'Tìm kiếm',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchView())),
          ),
          // Nút Cài đặt
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            tooltip: 'Cài đặt',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsView())),
          ),
          // Nút Góp ý
          IconButton(
            icon: const Icon(Icons.feedback, color: Colors.black87),
            tooltip: 'Góp ý',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FeedbackView())),
          ),
          // Nút Đăng xuất (đã có sẵn trước đó)
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await ref.read(authViewModelProvider).signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. BANNER TIN NÓNG (SLIDER)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Tin Nổi Bật 🔥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 200,
                child: StreamBuilder<QuerySnapshot>(
                  key: const ValueKey('hot_articles_stream'),
                  stream: FirebaseFirestore.instance
                      .collection('articles')
                      .where('is_hot', isEqualTo: true)
                      .where('status', isEqualTo: 1)
                      .orderBy('published_at', descending: true)
                      .limit(5)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Không có tin nổi bật nào'));
                    }
                    final docs = snapshot.data!.docs;
                    return PageView.builder(
                      controller: PageController(viewportFraction: 0.9),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: NetworkImage(data['thumbnail_url'] ?? 'https://picsum.photos/600/400'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              data['title'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // 2. THANH CHUYÊN MỤC (TABS)
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    bool isSelected = _selectedCategory == cat['id'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(cat['name']!),
                        selected: isSelected,
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat['id']!;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              // 3. DANH SÁCH BÀI VIẾT THEO CHUYÊN MỤC
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Tin Mới Nhận', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _buildQueryStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('Chưa có bài viết nào trong chuyên mục này.')),
                    );
                  }
                  final articles = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      final item = articles[index].data() as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 3))
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['thumbnail_url'] ?? 'https://picsum.photos/150',
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(width: 90, height: 90, color: Colors.grey[200]),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['summary'] ?? '',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _buildQueryStream() {
    Query query = FirebaseFirestore.instance.collection('articles').where('status', isEqualTo: 1);

    if (_selectedCategory != 'ALL') {
      query = query.where('category_id', isEqualTo: _selectedCategory);
    }

    return query.orderBy('published_at', descending: true).snapshots();
  }
}