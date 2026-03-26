import 'package:flutter/material.dart';

class ChatMobile extends StatelessWidget {
  final Widget header;
  final Widget tabs;
  final Widget content;

  const ChatMobile({
    super.key,
    required this.header,
    required this.tabs,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        header,
        tabs,
        Expanded(child: content),
      ],
    );
  }
}
