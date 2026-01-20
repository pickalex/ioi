import 'package:flutter/material.dart';

class CupertinoPopover extends StatefulWidget {
  final Widget child;
  final Widget Function(
    BuildContext context,
    CupertinoPopoverController controller,
  )
  popoverBuilder;
  final bool onLongPress;
  final bool onTap;
  final double arrowWidth;
  final double arrowHeight;
  final double borderRadius;
  final double verticalGap;
  final double screenMargin;
  final Color? backgroundColor;
  final CupertinoPopoverController? controller;

  const CupertinoPopover({
    super.key,
    required this.child,
    required this.popoverBuilder,
    this.onLongPress = false,
    this.onTap = true,
    this.arrowWidth = 22.0,
    this.arrowHeight = 10.0,
    this.borderRadius = 8.0,
    this.verticalGap = 8.0,
    this.screenMargin = 8.0,
    this.backgroundColor,
    this.controller,
  });

  @override
  State<CupertinoPopover> createState() => _CupertinoPopoverState();
}

class _CupertinoPopoverState extends State<CupertinoPopover> {
  OverlayEntry? _overlayEntry;
  late CupertinoPopoverController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? CupertinoPopoverController();
    _controller._attach(this);
  }

  @override
  void didUpdateWidget(CupertinoPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller._detach();
      _controller = widget.controller ?? CupertinoPopoverController();
      _controller._attach(this);
    }
  }

  void _dismiss() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _showPopover() {
    _dismiss(); // 确保唯一性

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final anchorSize = renderBox.size;
    final anchorOffset = renderBox.localToGlobal(Offset.zero);
    final anchorCenterX = anchorOffset.dx + anchorSize.width / 2;
    final anchorCenterY = anchorOffset.dy + anchorSize.height / 2;

    final screenHeight = MediaQuery.of(context).size.height;
    // Remove static calculation
    // final isBelow = anchorCenterY < (screenHeight * 0.55);

    final effectiveBgColor =
        widget.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2C)
            : Colors.white);

    final verticalGap = widget.verticalGap;
    final screenMargin = widget.screenMargin;

    final bubbleLeftNotifier = ValueNotifier<double>(0.0);
    final isBelowNotifier = ValueNotifier<bool>(
      true,
    ); // Default to true, updated by delegate

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 点击背景关闭
            GestureDetector(
              onTap: _dismiss,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _PopoverLayoutDelegate(
                  anchorCenterX: anchorCenterX,
                  anchorCenterY: anchorCenterY,
                  anchorSize: anchorSize,
                  // isBelow: isBelow, // Pass notifier instead
                  isBelowNotifier: isBelowNotifier,
                  verticalGap: verticalGap,
                  screenMargin: screenMargin,
                  screenHeight: screenHeight,
                  onPositioned: (left) => bubbleLeftNotifier.value = left,
                ),
                child: CustomPaint(
                  painter: BubblePainter(
                    color: effectiveBgColor,
                    arrowWidth: widget.arrowWidth,
                    arrowHeight: widget.arrowHeight,
                    anchorCenterX: anchorCenterX,
                    bubbleLeftNotifier: bubbleLeftNotifier,
                    isBelowNotifier: isBelowNotifier, // Pass notifier
                    borderRadius: widget.borderRadius,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: widget.popoverBuilder(context, _controller),
                    ),
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
      onTap: widget.onTap ? _showPopover : null,
      onLongPress: widget.onLongPress ? _showPopover : null,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller._detach();
    _dismiss();
    super.dispose();
  }
}

class CupertinoPopoverController {
  _CupertinoPopoverState? _state;
  VoidCallback? _dismissCallback;

  void _attach(_CupertinoPopoverState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  void show() {
    _state?._showPopover();
  }

  void hide() {
    _state?._dismiss();
  }

  /// Compatibility with PopoverController interface
  void dismiss() {
    hide();
    _dismissCallback?.call();
  }

  void attach(VoidCallback callback) {
    _dismissCallback = callback;
  }

  bool get isShowing => _state?._overlayEntry != null;
}

class _PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  final double anchorCenterX;
  final double anchorCenterY;
  final Size anchorSize;
  final ValueNotifier<bool> isBelowNotifier;
  final double verticalGap;
  final double screenMargin;
  final double screenHeight;
  final Function(double left) onPositioned;

  _PopoverLayoutDelegate({
    required this.anchorCenterX,
    required this.anchorCenterY,
    required this.anchorSize,
    required this.isBelowNotifier,
    required this.verticalGap,
    required this.screenMargin,
    required this.screenHeight,
    required this.onPositioned,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen().copyWith(
      maxWidth: constraints.maxWidth - screenMargin * 2,
      maxHeight: screenHeight - screenMargin * 2, // Allow full height check
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double left = anchorCenterX - childSize.width / 2;
    left = left.clamp(
      screenMargin,
      size.width - screenMargin - childSize.width,
    );

    bool isBelow = true;
    final bottomSpace =
        screenHeight -
        (anchorCenterY + anchorSize.height / 2 + verticalGap + screenMargin);

    if (childSize.height > bottomSpace) {
      final topSpace =
          anchorCenterY - anchorSize.height / 2 - verticalGap - screenMargin;
      if (topSpace > bottomSpace) {
        isBelow = false;
      }
    }

    if (isBelowNotifier.value != isBelow) {
      Future.microtask(() => isBelowNotifier.value = isBelow);
    }

    double top;
    if (isBelow) {
      top = anchorCenterY + anchorSize.height / 2 + verticalGap;
    } else {
      top =
          anchorCenterY -
          anchorSize.height / 2 -
          verticalGap -
          childSize.height;
    }

    onPositioned(left);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _PopoverLayoutDelegate oldDelegate) {
    return oldDelegate.anchorCenterX != anchorCenterX ||
        oldDelegate.anchorCenterY != anchorCenterY ||
        oldDelegate.screenHeight != screenHeight ||
        oldDelegate.isBelowNotifier != isBelowNotifier;
  }
}

class BubblePainter extends CustomPainter {
  final Color color;
  final double arrowWidth;
  final double arrowHeight;
  final double anchorCenterX;
  final ValueNotifier<double> bubbleLeftNotifier;
  final ValueNotifier<bool> isBelowNotifier;
  final double borderRadius;

  BubblePainter({
    required this.color,
    required this.arrowWidth,
    required this.arrowHeight,
    required this.anchorCenterX,
    required this.bubbleLeftNotifier,
    required this.isBelowNotifier,
    required this.borderRadius,
  }) : super(repaint: Listenable.merge([bubbleLeftNotifier, isBelowNotifier]));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();

    final r = borderRadius;
    const tr = 2.0;

    final isBelow = isBelowNotifier.value;

    final arrowX = anchorCenterX - bubbleLeftNotifier.value;
    final safeArrowX = arrowX.clamp(
      r + arrowWidth / 2,
      size.width - r - arrowWidth / 2,
    );

    if (isBelow) {
      path.moveTo(r, 0);
      path.lineTo(safeArrowX - arrowWidth / 2, 0);
      path.lineTo(safeArrowX - tr, -arrowHeight + tr);
      path.quadraticBezierTo(
        safeArrowX,
        -arrowHeight - tr * 0.2,
        safeArrowX + tr,
        -arrowHeight + tr,
      );
      path.lineTo(safeArrowX + arrowWidth / 2, 0);
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
      path.lineTo(safeArrowX + arrowWidth / 2, size.height);
      path.lineTo(safeArrowX + tr, size.height + arrowHeight - tr);
      path.quadraticBezierTo(
        safeArrowX,
        size.height + arrowHeight + tr * 0.2,
        safeArrowX - tr,
        size.height + arrowHeight - tr,
      );
      path.lineTo(safeArrowX - arrowWidth / 2, size.height);
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
        oldDelegate.anchorCenterX != anchorCenterX ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isBelowNotifier != isBelowNotifier;
  }
}
