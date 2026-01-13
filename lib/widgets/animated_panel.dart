import 'package:animated_switcher_plus/animated_switcher_plus.dart';
import 'package:flutter/material.dart';

enum AnimationType {
  none,
  fade,
  flipX,
  flipY,
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  zoomIn,
  zoomOut,
}

/// 通用动画切换容器
/// builder 返回的 widget 需要带有 key 以触发动画切换
class AnimatedPanel extends StatelessWidget {
  final WidgetBuilder builder;
  final AnimationType animationType;
  final Duration duration;
  final bool animateSize;
  final bool clipContent;

  const AnimatedPanel({
    super.key,
    required this.builder,
    this.animationType = AnimationType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.animateSize = true,
    this.clipContent = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = builder(context);

    content = _applyAnimation(content);

    if (clipContent) {
      content = ClipRect(clipBehavior: Clip.hardEdge, child: content);
    }

    if (animateSize) {
      content = AnimatedSize(duration: duration, child: content);
    }

    return content;
  }

  Widget _applyAnimation(Widget child) {
    switch (animationType) {
      case AnimationType.none:
        return child;
      case AnimationType.fade:
        return AnimatedSwitcher(duration: duration, child: child);
      case AnimationType.flipX:
        return AnimatedSwitcherPlus.flipX(duration: duration, child: child);
      case AnimationType.flipY:
        return AnimatedSwitcherPlus.flipY(duration: duration, child: child);
      case AnimationType.slideUp:
        return AnimatedSwitcherPlus.translationTop(
          duration: duration,
          child: child,
        );
      case AnimationType.slideDown:
        return AnimatedSwitcherPlus.translationBottom(
          duration: duration,
          child: child,
        );
      case AnimationType.slideLeft:
        return AnimatedSwitcherPlus.translationLeft(
          duration: duration,
          child: child,
        );
      case AnimationType.slideRight:
        return AnimatedSwitcherPlus.translationRight(
          duration: duration,
          child: child,
        );
      case AnimationType.zoomIn:
        return AnimatedSwitcherPlus.zoomIn(duration: duration, child: child);
      case AnimationType.zoomOut:
        return AnimatedSwitcherPlus.zoomOut(duration: duration, child: child);
    }
  }
}
