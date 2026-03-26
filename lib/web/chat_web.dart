import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'aurbit_web_theme.dart'; // AurbitWebTheme tokens

class ChatWeb extends StatelessWidget {
  final Widget header;
  final Widget tabs;
  final Widget sideListContent;
  final Widget? conversationContent;
  final VoidCallback? onBack;

  const ChatWeb({
    super.key,
    required this.header,
    required this.tabs,
    required this.sideListContent,
    this.conversationContent,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AurbitWebTheme.darkBg      : AurbitWebTheme.lightBg;
    final panelBg   = isDark ? AurbitWebTheme.darkSidebar : AurbitWebTheme.lightCard;
    final border    = isDark ? AurbitWebTheme.darkBorder   : AurbitWebTheme.lightBorder;
    final textColor = isDark ? AurbitWebTheme.darkText     : AurbitWebTheme.lightText;
    final subColor  = isDark ? AurbitWebTheme.darkSubtext  : AurbitWebTheme.lightSubtext;

    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth <= 800;

    if (isNarrow) {
      if (conversationContent != null) {
        return Container(
          color: bg,
          child: Column(
            children: [
              if (onBack != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: textColor),
                        onPressed: onBack,
                      ),
                      Text('Back to Chats', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              Expanded(child: conversationContent!),
            ],
          ),
        );
      }
      return Container(
        color: bg,
        child: Column(
          children: [
            header,
            tabs,
            Expanded(child: sideListContent),
          ],
        ),
      );
    }

    return Container(
      color: bg,
      child: Row(
        children: [
          // ── Left Chat List Panel ────────────────────────────────────
          Container(
            width: 360,
            decoration: BoxDecoration(
              color: panelBg,
              border: Border(right: BorderSide(color: border, width: 1)),
            ),
            child: Column(
              children: [
                header,
                tabs,
                Expanded(child: sideListContent),
              ],
            ),
          ),

          // ── Right: Conversation / Placeholder ──────────────────────
          Expanded(
            child: Container(
              color: isDark ? Colors.black : Colors.white,
              child: conversationContent ?? Column(
                children: [
                  // Top Panel Header
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Messages', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Select a conversation to start chatting',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'When you click on a message, it will show up here.',
                              style: GoogleFonts.inter(fontSize: 15, color: subColor),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AurbitWebTheme.accentPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('Add to Orbit', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
