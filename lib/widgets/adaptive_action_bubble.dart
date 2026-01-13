import 'package:flutter/material.dart';

class AdaptiveActionBubble extends StatefulWidget {
  final Widget child;
  final Widget Function(
    BuildContext context,
    AdaptiveActionBubbleController controller,
  )
  builder;
  final bool onLongPress;
  final bool onTap;
  final double arrowWidth;
  final double arrowHeight;
  final double borderRadius;
  final Color? backgroundColor;
  final AdaptiveActionBubbleController? controller;

  const AdaptiveActionBubble({
    super.key,
    required this.child,
    required this.builder,
    this.onLongPress = true,
    this.onTap = false,
    this.arrowWidth = 22.0,
    this.arrowHeight = 10.0,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.controller,
  });

  @override
  State<AdaptiveActionBubble> createState() => _AdaptiveActionBubbleState();
}

class _AdaptiveActionBubbleState extends State<AdaptiveActionBubble> {
  OverlayEntry? _overlayEntry;
  late final AdaptiveActionBubbleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AdaptiveActionBubbleController();
    _controller._attach(this);
  }

  @override
  void didUpdateWidget(AdaptiveActionBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  void _dismiss() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _showBubble() {
    _dismiss();

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final anchorSize = renderBox.size;
    final anchorOffset = renderBox.localToGlobal(Offset.zero);
    final anchorCenterX = anchorOffset.dx + anchorSize.width / 2;
    final anchorCenterY = anchorOffset.dy + anchorSize.height / 2;

    final screenHeight = MediaQuery.of(context).size.height;

    final effectiveBgColor =
        widget.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2C)
            : Colors.white);

    const verticalGap = 30.0;
    const screenMargin = 16.0;

    final bool isBelow = anchorCenterY < (screenHeight / 2);
    // 箭头在气泡内部的相对 X 坐标 (气泡是固定左右边距的)
    final arrowX = anchorCenterX - screenMargin;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _dismiss,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
            // 白点指示器
            Positioned(
              left: anchorCenterX - 12,
              top: anchorCenterY - 12,
              child: IgnorePointer(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            // 气泡卡片
            Positioned(
              left: screenMargin,
              right: screenMargin,
              top: isBelow ? anchorCenterY + verticalGap : null,
              bottom: isBelow
                  ? null
                  : screenHeight - (anchorCenterY - verticalGap),
              child: CustomPaint(
                painter: BubblePainter(
                  color: effectiveBgColor,
                  arrowWidth: widget.arrowWidth,
                  arrowHeight: widget.arrowHeight,
                  arrowX: arrowX,
                  isBelow: isBelow,
                  borderRadius: widget.borderRadius,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: widget.builder(context, _controller),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ? _showBubble : null,
      onLongPress: widget.onLongPress ? _showBubble : null,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _dismiss();
    super.dispose();
  }
}

class AdaptiveActionBubbleController {
  _AdaptiveActionBubbleState? _state;
  VoidCallback? _dismissCallback;

  void _attach(_AdaptiveActionBubbleState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  void show() {
    _state?._showBubble();
  }

  void hide() {
    _state?._dismiss();
  }

  /// Compatibility with PopoverController interface if needed
  void dismiss() {
    hide();
    _dismissCallback?.call();
  }

  void attach(VoidCallback callback) {
    _dismissCallback = callback;
  }

  bool get isShowing => _state?._overlayEntry != null;
}

class BubblePainter extends CustomPainter {
  final Color color;
  final double arrowWidth;
  final double arrowHeight;
  final double arrowX;
  final bool isBelow;
  final double borderRadius;

  BubblePainter({
    required this.color,
    required this.arrowWidth,
    required this.arrowHeight,
    required this.arrowX,
    required this.isBelow,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    final r = borderRadius;
    const tr = 2.0;

    if (isBelow) {
      path.moveTo(r, 0);
      path.lineTo(arrowX - arrowWidth / 2, 0);
      path.lineTo(arrowX - tr, -arrowHeight + tr);
      path.quadraticBezierTo(
        arrowX,
        -arrowHeight - tr * 0.2,
        arrowX + tr,
        -arrowHeight + tr,
      );
      path.lineTo(arrowX + arrowWidth / 2, 0);
      path.lineTo(size.width - r, 0);
      path.quadraticBezierTo(size.width, 0, size.width, r);
      path.lineTo(size.width, size.height - r);
      path.quadraticBezierTo(
        size.width,
        size.height,
        size.width - r,
        size.height,
      );
      path.lineTo(r, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - r);
      path.lineTo(0, r);
      path.quadraticBezierTo(0, 0, r, 0);
    } else {
      path.moveTo(r, 0);
      path.lineTo(size.width - r, 0);
      path.quadraticBezierTo(size.width, 0, size.width, r);
      path.lineTo(size.width, size.height - r);
      path.quadraticBezierTo(
        size.width,
        size.height,
        size.width - r,
        size.height,
      );
      path.lineTo(arrowX + arrowWidth / 2, size.height);
      path.lineTo(arrowX + tr, size.height + arrowHeight - tr);
      path.quadraticBezierTo(
        arrowX,
        size.height + arrowHeight + tr * 0.2,
        arrowX - tr,
        size.height + arrowHeight - tr,
      );
      path.lineTo(arrowX - arrowWidth / 2, size.height);
      path.lineTo(r, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - r);
      path.lineTo(0, r);
      path.quadraticBezierTo(0, 0, r, 0);
    }

    canvas.drawShadow(
      path.shift(const Offset(0, 2)),
      Colors.black.withOpacity(0.12),
      12.0,
      true,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.arrowX != arrowX ||
        oldDelegate.isBelow != isBelow;
  }
}
