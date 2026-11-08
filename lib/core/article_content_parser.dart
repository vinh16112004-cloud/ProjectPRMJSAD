class ArticleContentParser {
  /// Chuyển đổi nội dung chứa HTML hoặc văn bản thuần sang Markdown
  /// để tương thích hoàn toàn với Flutter MarkdownBody.
  static String parseToMarkdown(String input) {
    if (input.isEmpty) return '';

    String text = input;

    // Chuẩn hóa dòng ngắt và đoạn văn
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');

    // Tiêu đề h1 -> h6
    text = text.replaceAllMapped(
      RegExp(r'<h([1-6])[^>]*>(.*?)</h\1>', caseSensitive: false),
      (match) {
        final level = int.tryParse(match.group(1) ?? '2') ?? 2;
        final hashes = '#' * (level > 3 ? 3 : level);
        return '\n\n$hashes ${match.group(2)?.trim()}\n\n';
      },
    );

    // Chữ đậm và in nghiêng
    text = text.replaceAllMapped(
      RegExp(r'<(?:b|strong)[^>]*>(.*?)</(?:b|strong)>', caseSensitive: false),
      (match) => '**${match.group(1) ?? ''}**',
    );
    text = text.replaceAllMapped(
      RegExp(r'<(?:i|em)[^>]*>(.*?)</(?:i|em)>', caseSensitive: false),
      (match) => '*${match.group(1) ?? ''}*',
    );

    // Hình ảnh: <img ... src="..." ... alt="..." /> -> ![alt](url)
    text = text.replaceAllMapped(
      RegExp(r"""<img[^>]+src=["']([^"']+)["'][^>]*>""", caseSensitive: false),
      (match) {
        final src = match.group(1) ?? '';
        return '\n\n![]($src)\n\n';
      },
    );

    // Đường dẫn: <a href="...">label</a> -> [label](href)
    text = text.replaceAllMapped(
      RegExp(r"""<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)</a>""", caseSensitive: false),
      (match) {
        final href = match.group(1) ?? '';
        final label = match.group(2) ?? href;
        return '[$label]($href)';
      },
    );

    // Trích dẫn blockquote
    text = text.replaceAll(RegExp(r'<blockquote[^>]*>', caseSensitive: false), '\n> ');
    text = text.replaceAll(RegExp(r'</blockquote>', caseSensitive: false), '\n\n');

    // Loại bỏ thẻ HTML còn sót lại nếu có
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Giải mã HTML Entities thông dụng
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    return text.trim();
  }
}
