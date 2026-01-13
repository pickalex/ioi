import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 通知显示模式
enum NotificationMode { single, stack }

/// 通知样式预设
enum NotifyStyle { info, success, warning, error }

/// 通知模型
class _NotifyItem {
  final String id;
  final String message;
  final NotifyStyle style;
  final Widget Function(String message, VoidCallback onClose)? builder;
  Timer? timer;

  _NotifyItem({
    required this.id,
    required this.message,
    this.style = NotifyStyle.info,
    this.builder,
  });
}

class DialogService {
  static const String _loadingTag = 'global_loading';

  static Future<T?> runWithLoading<T>({
    required Future<T> task,
    String msg = '加载中...',
    Duration timeout = const Duration(seconds: 15),
    Widget Function(BuildContext, String)? builder,
  }) async {
    SmartDialog.show(
      tag: _loadingTag,
      backType: SmartBackType.block,
      clickMaskDismiss: false,
      maskColor: Colors.black45,
      builder: (ctx) =>
          builder != null ? builder(ctx, msg) : _DefaultLoadingUI(message: msg),
    );
    try {
      return await task.timeout(timeout);
    } catch (e) {
      debugPrint('Loading Error: $e');
      return null;
    } finally {
      await Future.delayed(const Duration(milliseconds: 80));
      SmartDialog.dismiss(tag: _loadingTag);
    }
  }

  static const String _notifyTag = 'global_notify';
  static const int _maxNotifications = 3;
  static final List<_NotifyItem> _items = [];
  static GlobalKey<AnimatedListState>? _listKey;
  static bool _isContainerShown = false;

  /// 全局配置：通知显示位置（默认顶部居中）
  static Alignment notificationAlignment = Alignment.topCenter;

  static void showNotification(
    String message, {
    NotificationMode mode = NotificationMode.single,
    NotifyStyle style = NotifyStyle.info,
    Widget Function(String message, VoidCallback onClose)? builder,
  }) {
    if (mode == NotificationMode.single && _items.isNotEmpty) {
      _clearAll();
    }

    final containerExists = SmartDialog.checkExist(tag: _notifyTag);

    if (!containerExists) {
      _listKey = GlobalKey<AnimatedListState>();
      _isContainerShown = true;
      _showNotifyContainer();
      Future.delayed(
        const Duration(milliseconds: 80),
        () => _insertItem(message, style: style, builder: builder),
      );
    } else {
      _insertItem(message, style: style, builder: builder);
    }
  }

  static void success(
    String message, {
    NotificationMode mode = NotificationMode.single,
  }) => showNotification(message, mode: mode, style: NotifyStyle.success);

  static void error(
    String message, {
    NotificationMode mode = NotificationMode.single,
  }) => showNotification(message, mode: mode, style: NotifyStyle.error);

  static void warning(
    String message, {
    NotificationMode mode = NotificationMode.single,
  }) => showNotification(message, mode: mode, style: NotifyStyle.warning);

  static void info(
    String message, {
    NotificationMode mode = NotificationMode.single,
  }) => showNotification(message, mode: mode, style: NotifyStyle.info);

  static void custom(
    String message, {
    required Widget Function(String message, VoidCallback onClose) builder,
    NotificationMode mode = NotificationMode.single,
  }) => showNotification(message, mode: mode, builder: builder);

  static void _insertItem(
    String message, {
    NotifyStyle style = NotifyStyle.info,
    Widget Function(String message, VoidCallback onClose)? builder,
  }) {
    if (_items.length >= _maxNotifications) {
      _removeItem(_items.last.id);
    }

    final item = _NotifyItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      style: style,
      builder: builder,
    );

    _items.insert(0, item);
    _listKey?.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 350),
    );

    item.timer = Timer(const Duration(seconds: 5), () => _removeItem(item.id));
  }

  static void _removeItem(String id) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final removed = _items.removeAt(idx);
    removed.timer?.cancel();

    _listKey?.currentState?.removeItem(
      idx,
      (ctx, anim) => _buildAnimatedItem(removed, anim),
      duration: const Duration(milliseconds: 250),
    );

    if (_items.isEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_items.isEmpty && _isContainerShown) {
          SmartDialog.dismiss(tag: _notifyTag);
          _isContainerShown = false;
        }
      });
    }
  }

  static void _clearAll() {
    final itemsCopy = List<_NotifyItem>.from(_items);

    for (var item in itemsCopy) {
      item.timer?.cancel();
    }

    for (int i = itemsCopy.length - 1; i >= 0; i--) {
      _listKey?.currentState?.removeItem(
        i,
        (ctx, anim) => _buildAnimatedItem(itemsCopy[i], anim),
        duration: const Duration(milliseconds: 150),
      );
    }
    _items.clear();
  }

  static Widget _buildAnimatedItem(_NotifyItem item, Animation<double> anim) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      axisAlignment: -1,
      child: FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.5, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutQuart)),
          child: _NotifyCard(item: item, onClose: () => _removeItem(item.id)),
        ),
      ),
    );
  }

  static void _showNotifyContainer() {
    final isTop = notificationAlignment.y <= 0;
    final padding = isTop
        ? const EdgeInsets.only(top: 8)
        : const EdgeInsets.only(bottom: 8);

    SmartDialog.show(
      tag: _notifyTag,
      alignment: notificationAlignment,
      usePenetrate: true,
      maskColor: Colors.transparent,
      animationType: SmartAnimationType.fade,
      animationTime: const Duration(milliseconds: 150),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: padding,
            child: AnimatedList(
              key: _listKey,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              initialItemCount: _items.length,
              itemBuilder: (ctx, idx, anim) =>
                  _buildAnimatedItem(_items[idx], anim),
            ),
          ),
        );
      },
    );
  }
}

class _DefaultLoadingUI extends StatelessWidget {
  final String message;
  const _DefaultLoadingUI({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 14),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                decoration: TextDecoration.none,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotifyCard extends StatelessWidget {
  final _NotifyItem item;
  final VoidCallback onClose;
  const _NotifyCard({required this.item, required this.onClose});

  @override
  Widget build(BuildContext context) {
    if (item.builder != null) {
      return item.builder!(item.message, onClose);
    }

    final (color, icon) = _getStyleConfig(item.style);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  static (Color, IconData) _getStyleConfig(NotifyStyle style) {
    switch (style) {
      case NotifyStyle.success:
        return (Colors.green, Icons.check_circle);
      case NotifyStyle.error:
        return (Colors.red, Icons.error);
      case NotifyStyle.warning:
        return (Colors.orange, Icons.warning_amber_rounded);
      case NotifyStyle.info:
        return (Colors.blueAccent, Icons.info);
    }
  }
}
