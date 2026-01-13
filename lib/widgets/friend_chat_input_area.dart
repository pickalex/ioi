import 'package:flutter/material.dart';
import 'chat_panel_controller.dart';

class FriendChatInputArea extends StatelessWidget {
  final TextEditingController messageController;
  final ChatPanelController panelController;
  final VoidCallback onSend;
  final VoidCallback onToggleEmoji;

  const FriendChatInputArea({
    super.key,
    required this.messageController,
    required this.panelController,
    required this.onSend,
    required this.onToggleEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {},
          ),
          Expanded(
            child: GestureDetector(
              onTap: panelController.handleInputTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: messageController,
                  focusNode: panelController.focusNode,
                  scrollController: panelController.scrollController,
                  readOnly: panelController.readOnly,
                  showCursor: true,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: panelController,
            builder: (context, _) {
              final isInputActive =
                  panelController.focusNode.hasFocus ||
                  panelController.readOnly;
              return IconButton(
                onPressed: onToggleEmoji,
                icon: Icon(
                  Icons.sentiment_satisfied_alt_outlined,
                  color: isInputActive
                      ? const Color(0xFFFF4D4D)
                      : Colors.black45,
                  size: 24,
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: messageController,
            builder: (context, child) {
              final showSend = messageController.text.trim().isNotEmpty;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: showSend
                    ? TextButton(onPressed: onSend, child: const Text('Send'))
                    : const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }
}
