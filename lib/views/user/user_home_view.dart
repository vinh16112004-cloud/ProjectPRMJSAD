import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:untitled1/models/article_model.dart';
import 'package:untitled1/models/category_model.dart';
import 'package:untitled1/viewmodels/auth_viewmodel.dart';
import 'dart:convert';
import 'package:untitled1/viewmodels/profile_viewmodel.dart';
import 'article_detail_view.dart';
import 'feedback_view.dart';
import 'profile_view.dart';
import 'search_view.dart';
import 'settings_view.dart';

class UserHomeView extends ConsumerStatefulWidget {
  const UserHomeView({super.key});

  @override
  ConsumerState<UserHomeView> createState() => _UserHomeViewState();
}

class _UserHomeViewState extends ConsumerState<UserHomeView> {
  String _selectedCategory = 'ALL';
  final PageController _hotPageController = PageController(
    viewportFraction: 0.9,
  );

  // Stream danh mục
  late final Stream<List<CategoryModel>> _categoryStream;

  // Stream bài viết
  late final Stream<List<ArticleModel>> _articleStream;

  @override
  void initState() {
    super.initState();
    _categoryStream = _buildCategoryStream();
    _articleStream = _buildArticleStream();
  }

  @override
  void dispose() {
    _hotPageController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. LẤY DANH SÁCH DANH MỤC
  // ==========================================

  Stream<List<CategoryModel>> _buildCategoryStream() {
    return FirebaseFirestore.instance.collection('categories').snapshots().map((
        snapshot,
        ) {
      final categories = snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
          .where((category) => category.isActive)
          .toList();

      categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return categories;
    });
  }

  // ==========================================
  // 2. LẤY DANH SÁCH BÀI VIẾT ĐÃ XUẤT BẢN
  // ==========================================

  Stream<List<ArticleModel>> _buildArticleStream() {
    return FirebaseFirestore.instance
        .collection('articles')
        .where('status', isEqualTo: 1)
        .snapshots()
        .map((snapshot) {
      final articles = snapshot.docs.map((doc) {
        return ArticleModel.fromMap(doc.data(), doc.id);
      }).toList();
      articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return articles;
    });
  }

  // ==========================================
  // 3. LÀM MỚI DỮ LIỆU
  // ==========================================

  Future<void> _refreshData() async {
    await Future.wait([
      FirebaseFirestore.instance
          .collection('articles')
          .where('status', isEqualTo: 1)
          .get(),
      FirebaseFirestore.instance.collection('categories').get(),
    ]);
  }

  // ==========================================
  // 4. HIỂN THỊ GIAO DIỆN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateChangesProvider).valueOrNull;

    final profileState = currentUser == null
        ? null
        : ref.watch(userProfileProvider(currentUser.uid));
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Báo Mới 24h - Dành cho bạn',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // Tìm kiếm
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            tooltip: 'Tìm kiếm',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchView()),
              );
            },
          ),

          // Cài đặt
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            tooltip: 'Cài đặt',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsView()),
              );
            },
          ),

          // Góp ý
          IconButton(
            icon: const Icon(Icons.feedback, color: Colors.black87),
            tooltip: 'Góp ý',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeedbackView()),
              );
            },
          ),

          if (currentUser == null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Đăng nhập'),
              ),
            )
          else ...[
            // Hồ sơ cá nhân: hiển thị ảnh đại diện đã cập nhật
            IconButton(
              tooltip: 'Hồ sơ cá nhân',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileView(),
                  ),
                );
              },
              icon: profileState == null
                  ? const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person, size: 20),
              )
                  : profileState.when(
                data: (profile) {
                  if (profile == null) {
                    return const CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person, size: 20),
                    );
                  }

                  ImageProvider? avatarImage;

                  if (profile.avatarUrl.startsWith('data:image/')) {
                    try {
                      avatarImage = MemoryImage(
                        base64Decode(profile.avatarUrl.split(',').last),
                      );
                    } catch (_) {
                      avatarImage = null;
                    }
                  } else if (profile.avatarUrl.isNotEmpty) {
                    avatarImage = NetworkImage(profile.avatarUrl);
                  }

                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.deepPurple.shade100,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                      profile.fullName.isEmpty
                          ? '?'
                          : profile.fullName[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : null,
                  );
                },
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person, size: 20),
                ),
              ),
            ),
            // Đăng xuất
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'Đăng xuất',
              onPressed: () async {
                await ref.read(authViewModelProvider).signOut();
              },
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: StreamBuilder<List<ArticleModel>>(
          stream: _articleStream,
          builder: (context, articleSnapshot) {
            if (articleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (articleSnapshot.hasError) {
              return _buildError(
                'Không thể tải bài viết',
                articleSnapshot.error.toString(),
              );
            }

            final allArticles = articleSnapshot.data ?? [];

            final hotArticles = allArticles
                .where((article) => article.isHot)
                .take(5)
                .toList();

            final filteredArticles = _selectedCategory == 'ALL'
                ? allArticles
                : allArticles
                .where(
                  (article) => article.categoryId == _selectedCategory,
            )
                .toList();

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Tin Nổi Bật 🔥',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildHotArticles(hotArticles),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Chuyên mục',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  StreamBuilder<List<CategoryModel>>(
                    stream: _categoryStream,
                    builder: (context, categorySnapshot) {
                      if (categorySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox(
                          height: 50,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (categorySnapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Lỗi tải danh mục: ${categorySnapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final categories = categorySnapshot.data ?? [];
                      return _buildCategoryList(categories);
                    },
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      _selectedCategory == 'ALL'
                          ? 'Tin Mới Nhận'
                          : 'Bài viết theo chuyên mục',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (filteredArticles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Chưa có bài viết nào trong chuyên mục này.',
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredArticles.length,
                      itemBuilder: (context, index) {
                        final article = filteredArticles[index];
                        return _buildArticleItem(article);
                      },
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 5. WIDGET TIN NỔI BẬT
  // ==========================================

  Widget _buildHotArticles(List<ArticleModel> articles) {
    if (articles.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Chưa có tin nổi bật')),
      );
    }

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _hotPageController,
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArticleDetailView(article: article),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildArticleImage(
                          article.thumbnailUrl,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Text(
                            article.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  if (articles.length > 1 && _hotPageController.hasClients) {
                    final currentPage = (_hotPageController.page ?? 0).round();
                    final previousPage =
                        (currentPage - 1 + articles.length) % articles.length;
                    _hotPageController.animateToPage(
                      previousPage,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ),
          Positioned(
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  if (articles.length > 1 && _hotPageController.hasClients) {
                    final currentPage = (_hotPageController.page ?? 0).round();
                    final nextPage = (currentPage + 1) % articles.length;
                    _hotPageController.animateToPage(
                      nextPage,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. WIDGET DANH SÁCH DANH MỤC
  // ==========================================

  Widget _buildCategoryList(List<CategoryModel> categories) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildCategoryChip(id: 'ALL', name: 'Khám phá', iconUrl: ''),
          ...categories.map((category) {
            return _buildCategoryChip(
              id: category.id,
              name: category.name,
              iconUrl: category.iconUrl,
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 7. WIDGET TỪNG DANH MỤC
  // ==========================================

  Widget _buildCategoryChip({
    required String id,
    required String name,
    required String iconUrl,
  }) {
    final isSelected = _selectedCategory == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = id;
        });
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue
                    : Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: iconUrl.isNotEmpty
                  ? ClipOval(
                child: Image.network(
                  iconUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.category,
                      color: isSelected ? Colors.white : Colors.blue,
                    );
                  },
                ),
              )
                  : Icon(
                Icons.category,
                color: isSelected ? Colors.white : Colors.blue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 8. WIDGET TỪNG BÀI VIẾT
  // ==========================================

  Widget _buildArticleItem(ArticleModel article) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailView(article: article),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildArticleImage(
                article.thumbnailUrl,
                width: 90,
                height: 90,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.summary,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tác giả: ${article.author}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.isHot)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: Colors.red,
                            size: 15,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Tin nổi bật',
                            style: TextStyle(color: Colors.red, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 9. WIDGET HIỂN THỊ ẢNH
  // ==========================================

  Widget _buildArticleImage(
      String imageUrl, {
        required double width,
        required double height,
      }) {
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }

  // ==========================================
  // 10. WIDGET HIỂN THỊ LỖI
  // ==========================================

  Widget _buildError(String title, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SelectableText(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
