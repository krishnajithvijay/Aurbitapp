import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches Open Graph metadata using the free microlink.io API.
/// Falls back gracefully if fetch fails.
class LinkPreviewService {
  static final _cache = <String, LinkPreviewData>{};

  static final _urlRegex = RegExp(
    r'https?://[^\s/$.?#].[^\s]*',
    caseSensitive: false,
  );

  /// Extracts the first URL found in [text], or null if none.
  static String? extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  /// Checks whether [text] contains a URL.
  static bool hasUrl(String text) => _urlRegex.hasMatch(text);

  /// Removes URLs from text for cleaner display while keeping previews.
  static String stripUrls(String text) {
    return text
        .replaceAll(_urlRegex, '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Fetches OG preview data for [url] using microlink.io.
  static Future<LinkPreviewData?> fetchPreview(String url) async {
    if (_cache.containsKey(url)) return _cache[url];

    try {
      final apiUrl = Uri.parse('https://api.microlink.io/?url=${Uri.encodeComponent(url)}');
      final response = await http.get(
        apiUrl,
        headers: const {
          'accept': 'application/json',
          'user-agent': 'AurbitApp-LinkPreview/1.0',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        final fallback = _buildFallback(url);
        _cache[url] = fallback;
        return fallback;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) {
        final fallback = _buildFallback(url);
        _cache[url] = fallback;
        return fallback;
      }

      final image = data['image'] as Map<String, dynamic>?;
      final screenshot = data['screenshot'] as Map<String, dynamic>?;

      final preview = LinkPreviewData(
        url: url,
        title: data['title']?.toString(),
        description: data['description']?.toString(),
        imageUrl: image?['url']?.toString() ?? screenshot?['url']?.toString() ?? _fallbackThumbnail(url),
        domain: _extractDomain(url),
        faviconUrl: (data['logo'] as Map<String, dynamic>?)?['url']?.toString(),
      );
      _cache[url] = preview;
      return preview;
    } catch (_) {
      // Return minimal fallback on error
      final fallback = _buildFallback(url);
      _cache[url] = fallback;
      return fallback;
    }
  }

  static LinkPreviewData _buildFallback(String url) {
    return LinkPreviewData(
      url: url,
      title: null,
      description: null,
      imageUrl: _fallbackThumbnail(url),
      domain: _extractDomain(url),
      faviconUrl: null,
    );
  }

  // Generic screenshot fallback when OG image is unavailable.
  static String _fallbackThumbnail(String url) {
    final normalized = (url.startsWith('http://') || url.startsWith('https://'))
        ? url
        : 'https://$url';
    // thum.io expects raw URL path (not URI-encoded string).
    return 'https://image.thum.io/get/width/1200/noanimate/$normalized';
  }

  static String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}

class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String domain;
  final String? faviconUrl;

  const LinkPreviewData({
    required this.url,
    required this.domain,
    this.title,
    this.description,
    this.imageUrl,
    this.faviconUrl,
  });
}
