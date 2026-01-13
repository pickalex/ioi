import 'package:flutter/material.dart';

class CustomHomeBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onGoLive;

  const CustomHomeBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onGoLive,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const double barHeight = 80;
    const double notchRadius = 38;

    return Container(
      height: barHeight + 20, // Extra space for the elevated FAB
      child: Stack(
        clipBehavior: Clip.none,

        children: [
          // Background Painter
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              size: Size(size.width, barHeight),
              painter: BottomBarPainter(),
            ),
          ),
          // Navigation Items
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.home_rounded, '首页'),
                _buildNavItem(1, Icons.people_rounded, '好友'),
                const SizedBox(width: notchRadius * 2), // Space for FAB
                _buildNavItem(2, Icons.message_rounded, '消息'),
                _buildNavItem(3, Icons.person_rounded, '我的'),
              ],
            ),
          ),
          // Central "Go Live" Button
          Positioned(
            top: 0,
            left: size.width / 2 - 32,
            child: GestureDetector(
              onTap: onGoLive,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF007AFF) : Colors.black38,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF007AFF) : Colors.black38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path();
    const double notchRadius = 45;
    const double cornerRadius = 25;

    // Start from top-left
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Line to the notch
    path.lineTo(size.width / 2 - notchRadius - 10, 0);

    // The Notch (smooth Bezier curve)
    path.quadraticBezierTo(
      size.width / 2 - notchRadius + 5,
      0,
      size.width / 2 - notchRadius + 10,
      10,
    );
    path.arcToPoint(
      Offset(size.width / 2 + notchRadius - 10, 10),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(
      size.width / 2 + notchRadius - 5,
      0,
      size.width / 2 + notchRadius + 10,
      0,
    );

    // Line to top-right
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    // Bottom parts
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Draw shadow first
    canvas.drawPath(path.shift(const Offset(0, -2)), shadowPaint);
    // Draw background
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
