import 'package:flutter/material.dart';
import 'package:live_app/utils/date_util.dart';

import '../models/chat_message.dart';


class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: _PaintedChatBubble(
              isMe: isMe,
              timestamp: message.timestamp,
              child: Text(
                message.content,
                style: const TextStyle(color: Color(0xFF191919), fontSize: 16),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        isMe
            ? 'https://picsum.photos/seed/me/100/100'
            : 'https://picsum.photos/seed/friend/100/100',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _PaintedChatBubble extends StatelessWidget {
  final Widget child;
  final bool isMe;
  final DateTime timestamp;

  const _PaintedChatBubble({
    required this.child,
    required this.isMe,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        CustomPaint(
          painter: _BubbleBackgroundPainter(
            color: isMe ? const Color(0xFF95EC69) : Colors.white,
            isMe: isMe,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: child,
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            timestamp.relativeTime,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  final Color color;
  final bool isMe;

  _BubbleBackgroundPainter({required this.color, required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final path = Path();
    const radius = 6.0;
    const tailWidth = 6.0;
    const tailHeight = 10.0;
    const tailTop = 12.0;

    if (isMe) {
      // Body
      path.addRRect(
        RRect.fromLTRBAndCorners(
          0,
          0,
          size.width,
          size.height,
          topLeft: const Radius.circular(radius),
          topRight: const Radius.circular(radius),
          bottomLeft: const Radius.circular(radius),
          bottomRight: const Radius.circular(radius),
        ),
      );
      // Tail
      path.moveTo(size.width, tailTop);
      path.lineTo(size.width + tailWidth, tailTop + tailHeight / 2);
      path.lineTo(size.width, tailTop + tailHeight);
    } else {
      // Body
      path.addRRect(
        RRect.fromLTRBAndCorners(
          0,
          0,
          size.width,
          size.height,
          topLeft: const Radius.circular(radius),
          topRight: const Radius.circular(radius),
          bottomLeft: const Radius.circular(radius),
          bottomRight: const Radius.circular(radius),
        ),
      );
      // Tail
      path.moveTo(0, tailTop);
      path.lineTo(-tailWidth, tailTop + tailHeight / 2);
      path.lineTo(0, tailTop + tailHeight);
    }

    // Shadow first
    canvas.drawPath(path.shift(const Offset(0, 1)), shadowPaint);
    // Fill
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
