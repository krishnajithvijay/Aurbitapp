import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/link_preview_service.dart';
import '../web/aurbit_web_theme.dart';

/// Renders an Open Graph link preview card.
/// Fetches metadata lazily on first build and caches the result.
class LinkPreviewCard extends StatefulWidget {
  final String url;
  final bool isDark;
  final Color borderColor;
  final Color cardBg;

  const LinkPreviewCard({
    super.key,
    required this.url,
    required this.isDark,
    required this.borderColor,
    required this.cardBg,
  });

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  LinkPreviewData? _data;
  bool _loading = true;
  bool _imageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final data = await LinkPreviewService.fetchPreview(widget.url);
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  Future<void> _open() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Proxy OG image through images.weserv.nl to bypass CORS on Flutter Web.
  String _proxyImage(String url) {
    // Keep fallback screenshot URLs as-is; double proxying can break them.
    if (url.contains('image.thum.io') || url.contains('images.weserv.nl')) {
      return url;
    }
    if (kIsWeb) {
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}&w=800&output=webp&il';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final textColor  = widget.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final subColor   = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final pillBg     = widget.isDark ? const Color(0xFF252530) : const Color(0xFFF1F5F9);
    final accent     = AurbitWebTheme.accentPrimary;

    if (_loading) {
      return _LoadingShell(isDark: widget.isDark, borderColor: widget.borderColor, cardBg: widget.cardBg);
    }

    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final hasImage = (data.imageUrl?.isNotEmpty ?? false) && !_imageLoadFailed;

    return GestureDetector(
      onTap: _open,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: widget.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.borderColor),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _proxyImage(data.imageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _imageLoadFailed = true);
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              // Metadata Container below the image
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Domain chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 11, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            data.domain.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (data.title != null)
                      Text(
                        data.title!,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (data.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        data.description!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: subColor,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 14, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          'Visit Link',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingShell extends StatelessWidget {
  final bool isDark;
  final Color borderColor;
  final Color cardBg;
  const _LoadingShell({required this.isDark, required this.borderColor, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final shimmer = isDark ? const Color(0xFF252530) : const Color(0xFFF1F5F9);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(width: 80, height: 80, color: shimmer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, width: 120, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(height: 8, width: 200, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
    );
  }
}
