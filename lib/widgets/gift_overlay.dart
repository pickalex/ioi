import 'dart:async';
import 'package:flutter/material.dart';

/// 礼物数据模型
class GiftAnimation {
  final String id;
  final String giftName;
  final String emoji;
  final String sender;

  GiftAnimation({
    required this.id,
    required this.giftName,
    required this.emoji,
    required this.sender,
  });
}

/// 礼物动画配置
class GiftAnimConfig {
  final Duration inDuration;
  final Duration outDuration;
  final Widget Function(BuildContext, Animation<double>, Widget) inBuilder;
  final Widget Function(BuildContext, Animation<double>, Widget) outBuilder;

  const GiftAnimConfig({
    this.inDuration = const Duration(milliseconds: 500),
    this.outDuration = const Duration(milliseconds: 300),
    required this.inBuilder,
    required this.outBuilder,
  });

  /// 预设：从左侧划入，(可选)向左划出或淡出
  factory GiftAnimConfig.slideLeft() {
    return GiftAnimConfig(
      inDuration: const Duration(milliseconds: 400),
      outDuration: const Duration(milliseconds: 300),
      inBuilder: (context, anim, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: const Offset(0.0, 0.0),
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      outBuilder: (context, anim, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  /// 预设：从底部淡入上浮，淡出
  factory GiftAnimConfig.fadeUp() {
    return GiftAnimConfig(
      inDuration: const Duration(milliseconds: 500),
      outDuration: const Duration(milliseconds: 300),
      inBuilder: (context, anim, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.5),
            end: const Offset(0.0, 0.0),
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutQuart)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      outBuilder: (context, anim, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }
}

class GiftOverlay extends StatefulWidget {
  final Stream<GiftAnimation> giftStream;
  final GiftAnimConfig config;

  const GiftOverlay({
    super.key,
    required this.giftStream,
    required this.config,
  });

  /// 命名构造函数：滑入风格
  factory GiftOverlay.slideLeft({
    Key? key,
    required Stream<GiftAnimation> giftStream,
  }) {
    return GiftOverlay(
      key: key,
      giftStream: giftStream,
      config: GiftAnimConfig.slideLeft(),
    );
  }

  /// 命名构造函数：上浮风格
  factory GiftOverlay.fadeUp({
    Key? key,
    required Stream<GiftAnimation> giftStream,
  }) {
    return GiftOverlay(
      key: key,
      giftStream: giftStream,
      config: GiftAnimConfig.fadeUp(),
    );
  }

  @override
  State<GiftOverlay> createState() => _GiftOverlayState();
}

class _GiftOverlayState extends State<GiftOverlay> {
  // 维护一个显示列表，这里的顺序是：[旧 ... 新]
  // 渲染时： index 0 是最上面的（Older），index last 是最下面的（Newer）
  // 实际上为了"Push Up"，最下面的应该是最新，所以 y 轴坐标大。最上面 y 轴坐标小。
  final List<_ActiveGiftItem> _activeItems = [];
  late StreamSubscription<GiftAnimation> _subscription;

  // 每一行的高度 + 间距
  final double _itemHeight = 60.0;
  final int _maxCount = 3;

  @override
  void initState() {
    super.initState();
    _subscription = widget.giftStream.listen(_onNewGift);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _onNewGift(GiftAnimation gift) {
    if (!mounted) return;
    setState(() {
      // 1. 如果已满，标记第一个（最旧的）为移除状态
      if (_activeItems.length >= _maxCount) {
        // 找到第一个还没被标记为 removing 的
        final validItems = _activeItems.where((e) => !e.isRemoving).toList();
        if (validItems.isNotEmpty) {
          final itemToRemove = validItems.first;
          itemToRemove.isRemoving = true;
          // 它的 key 还在树上，所以 _GiftItemWidget 会感知到 isRemoving 变化并执行 out 动画
          // 动画结束后回调会调用 _removeItem
        }
      }

      // 2. 添加新礼物到末尾
      _activeItems.add(
        _ActiveGiftItem(
          id: UniqueKey().toString(), // 确保唯一
          data: gift,
        ),
      );
    });
  }

  void _removeItem(String id) {
    if (!mounted) return;
    setState(() {
      _activeItems.removeWhere((item) => item.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 过滤出所有还没完全移除的项目进行布局计算
    // 渲染 Stack，需要计算每个 item 的 top。
    // 假设基准点（最新的礼物）在 top = 200 (或者相对 Stack 底部)
    // 这里我们使用 Stack + Positioned.
    // 我们定义：最新的在最下面。
    // Index i (在可视列表中，排除 isRemoving 的那些正在退出的可能需要特殊处理?)
    // 简单起见：
    // 我们倒序遍历 _activeItems 来决定位置。
    // 排除 isRemoving=true 的元素不参与"占位"计算（或者参与? 既然是 push up，旧的被顶上去，
    // 那么旧的退出时，是否应该保留位置?
    // 通常 UI：新进来了，旧的往上顶，最上面的顶出随着 fade out。
    // 所以即使 isRemoving，它也应该在那个被顶到的位置上播放退出动画。

    // 策略：
    // 列表：[A, B, C] -> 新增 D -> [A(remove), B, C, D]
    // A 位置：Top 0
    // B 位置：Top 1
    // C 位置：Top 2
    // D 位置：Top 3 (Bottom)
    // 这种坐标系下，新增 D，B/C/D 都在下面的位置。
    // 假设仅仅展示 3 个位置： Pos 0 (top), Pos 1, Pos 2 (bottom).
    // 当有 4 个 item 时：
    // A (isRemoving) -> 应该在 Pos -1 ? 或者还停留在 Pos 0 只要 fade out?
    // B -> Pos 0
    // C -> Pos 1
    // D -> Pos 2

    // 计算 logic index:
    // 只要不是 isRemoving 的，就从下往上数。
    // Newest (last valid) -> Slot 0 (Bottom)
    // Prev -> Slot 1
    // ...
    // isRemoving 的元素? 它们应该是"超出 Slot" 的位置。

    return LayoutBuilder(
      builder: (context, constraints) {
        List<Widget> children = [];
        final baseBottom =
            constraints.maxHeight * 0.2; // 20% from bottom as base

        for (int i = 0; i < _activeItems.length; i++) {
          final item = _activeItems[i];
          final reverseIndex = _activeItems.length - 1 - i;

          children.add(
            AnimatedPositioned(
              key: ValueKey(item.id),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 20,
              bottom: baseBottom + (reverseIndex * _itemHeight),
              child: _GiftItemWidget(
                item: item,
                config: widget.config,
                onRemove: () => _removeItem(item.id),
              ),
            ),
          );
        }

        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

class _ActiveGiftItem {
  final String id;
  final GiftAnimation data;
  bool isRemoving;

  _ActiveGiftItem({required this.id, required this.data}) : isRemoving = false;
}

class _GiftItemWidget extends StatefulWidget {
  final _ActiveGiftItem item;
  final GiftAnimConfig config;
  final VoidCallback onRemove;

  const _GiftItemWidget({
    required this.item,
    required this.config,
    required this.onRemove,
  });

  @override
  State<_GiftItemWidget> createState() => _GiftItemWidgetState();
}

class _GiftItemWidgetState extends State<_GiftItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.config.inDuration,
    );
    _controller.forward().then((_) {
      // In 动画完成后，设置个定时器自动消失?
      // 需求里没明确说"自动消失"，只说"送了三个之后先进先出"。
      // 但通常礼物展示几秒后会自己消失。我们加个 3秒自动消失吧，防止堆积。
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !widget.item.isRemoving) {
          widget.onRemove(); // 这会触发父级把 isRemoving 设为 true?
          // 不，父级的逻辑是 Full 时才设。如果我们想自动过期，需要调用父级方法。
          // 如果这里直接调 onRemove，父级直接 removeWhere，那么就没有 Out 动画了。
          // 应该通知父级 "Expire this item"。
          // 简化起见，这里暂不自动消失，完全依赖"先进先出"逻辑 (User Requested: "送了三个之后先进先出")
          // 这样用户能一直看到最后三个礼物。
        }
      });
    });
  }

  @override
  void didUpdateWidget(_GiftItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.isRemoving && !oldWidget.item.isRemoving) {
      // 触发退出动画
      _controller.duration = widget.config.outDuration;
      _controller.reverse().then((_) {
        widget.onRemove(); // 动画播完，真正物理移除
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 区分是 In 还是 Out
    // AnimationController: 0 -> 1 (In), 1 -> 0 (Out, via reverse)
    // 所以我们统复用 _controller。
    // InBuilder: anim 0->1.
    // OutBuilder: anim 1->0 ?
    // 通常 OutBuilder 期望 anim 0->1 (progress of exit)。
    // 但 _controller.reverse() 是 1->0。
    // 所以如果是 out 阶段，我们可能需要 child 包裹 OutBuilder，并传 (1 - controller.value)?
    // 或者简单点：OutAnimation 也是 0->1 的过程。
    // 为了灵活性：
    // 如果 isRemoving，我们应该让 UI 表现为 "Leaving"。
    //

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (widget.item.isRemoving) {
          // Out Phase
          // controller.value goes 1 -> 0
          // 我们可以定义 OutBuilder 接受 0->1 (exit progress)
          // exitProgress = 1.0 - controller.value
          // 但 controller.reverse 曲线可能不合适。
          // 简单实现：直接用 value。OutBuilder 负责处理 1->0 的效果 (e.g. Opacity = value)
          return widget.config.outBuilder(context, _controller, child!);
        } else {
          // In Phase
          return widget.config.inBuilder(context, _controller, child!);
        }
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    final gift = widget.item.data;
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 4, right: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(
              'https://picsum.photos/seed/${gift.giftName}/100/100',
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                gift.sender,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '送出 ${gift.giftName}',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Text(gift.emoji, style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}
