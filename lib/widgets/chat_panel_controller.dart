/// 聊天面板控制器
/// 基于官方 chat_bottom_container demo，提供简洁易用的 API
import 'package:chat_bottom_container/chat_bottom_container.dart';
import 'package:flutter/material.dart';

/// 面板类型枚举
enum ChatPanelType { none, keyboard, emoji, tool }

/// 聊天面板控制器
///
/// 用法示例:
/// ```dart
/// final controller = ChatPanelController();
///
/// // 在 build 方法中
/// TextField(
///   focusNode: controller.focusNode,
///   readOnly: controller.readOnly,
///   showCursor: true,
/// ),
///
/// ChatBottomPanelContainer<ChatPanelType>(
///   controller: controller.panelController,
///   inputFocusNode: controller.focusNode,
///   onPanelTypeChange: controller.onPanelTypeChange,
///   otherPanelWidget: (type) => controller.buildPanel(type),
/// ),
///
/// // 切换面板
/// controller.toggleEmoji();
/// controller.toggleTool();
/// ```
class ChatPanelController extends ChangeNotifier {
  /// 底层面板控制器
  final ChatBottomPanelContainerController<ChatPanelType> panelController =
      ChatBottomPanelContainerController<ChatPanelType>();

  /// 输入框焦点节点
  final FocusNode focusNode = FocusNode();

  /// 输入框 ScrollController
  final ScrollController scrollController = ScrollController();

  /// 当前面板类型
  ChatPanelType _currentPanelType = ChatPanelType.none;
  ChatPanelType get currentPanelType => _currentPanelType;

  /// 输入框是否只读
  bool _readOnly = false;
  bool get readOnly => _readOnly;

  /// 键盘高度
  double get keyboardHeight => panelController.keyboardHeight;

  /// 自定义面板构建器
  Widget Function(ChatPanelType type, double height)? panelBuilder;

  /// 更新 readOnly 状态，返回是否真正改变
  bool _updateReadOnly(bool isReadOnly) {
    if (_readOnly != isReadOnly) {
      _readOnly = isReadOnly;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 切换到指定面板类型
  void switchTo(ChatPanelType type) {
    final isSwitchToKeyboard = type == ChatPanelType.keyboard;
    final isSwitchToEmoji = type == ChatPanelType.emoji;
    final isSwitchToCustom =
        type == ChatPanelType.emoji || type == ChatPanelType.tool;

    bool isUpdated = false;
    if (isSwitchToKeyboard) {
      _updateReadOnly(false);
    } else if (isSwitchToCustom) {
      isUpdated = _updateReadOnly(true);
    }

    void doUpdatePanelType() {
      panelController.updatePanelType(
        isSwitchToKeyboard
            ? ChatBottomPanelType.keyboard
            : (type == ChatPanelType.none
                  ? ChatBottomPanelType.none
                  : ChatBottomPanelType.other),
        data: type,
        forceHandleFocus: isSwitchToEmoji
            ? ChatBottomHandleFocus.requestFocus
            : ChatBottomHandleFocus.none,
      );
    }

    if (isUpdated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        doUpdatePanelType();
      });
    } else {
      doUpdatePanelType();
    }
  }

  /// 切换表情面板
  void toggleEmoji() {
    switchTo(
      _currentPanelType == ChatPanelType.emoji
          ? ChatPanelType.keyboard
          : ChatPanelType.emoji,
    );
  }

  /// 切换工具面板
  void toggleTool() {
    switchTo(
      _currentPanelType == ChatPanelType.tool
          ? ChatPanelType.keyboard
          : ChatPanelType.tool,
    );
  }

  /// 隐藏面板
  void hidePanel() {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
    _updateReadOnly(false);
    if (panelController.currentPanelType != ChatBottomPanelType.none) {
      panelController.updatePanelType(ChatBottomPanelType.none);
    }
  }

  /// 关闭面板（hidePanel 的别名）
  void close() => hidePanel();

  /// 面板类型变化回调 - 需要传给 ChatBottomPanelContainer.onPanelTypeChange
  void onPanelTypeChange(ChatBottomPanelType panelType, ChatPanelType? data) {
    switch (panelType) {
      case ChatBottomPanelType.none:
        _currentPanelType = ChatPanelType.none;
        break;
      case ChatBottomPanelType.keyboard:
        _currentPanelType = ChatPanelType.keyboard;
        break;
      case ChatBottomPanelType.other:
        if (data != null) {
          _currentPanelType = data;
        }
        break;
    }
    notifyListeners();
  }

  /// 输入框点击处理 - 当 readOnly 时切换到键盘
  void handleInputTap() {
    if (_readOnly) {
      switchTo(ChatPanelType.keyboard);
    }
  }

  /// 获取面板高度
  double getPanelHeight([double defaultHeight = 300]) {
    return keyboardHeight > 0 ? keyboardHeight : defaultHeight;
  }

  @override
  void dispose() {
    focusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
