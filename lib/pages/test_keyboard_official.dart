/// 官方 chat_bottom_container 示例的简化版本
/// 不使用 GetX，直接用 StatefulWidget + setState
import 'package:chat_bottom_container/chat_bottom_container.dart';
import 'package:flutter/material.dart';

/// 面板类型枚举
enum PanelType { none, keyboard, emoji, tool }

class TestKeyboardOfficial extends StatefulWidget {
  const TestKeyboardOfficial({super.key});

  @override
  State<TestKeyboardOfficial> createState() => _TestKeyboardOfficialState();
}

class _TestKeyboardOfficialState extends State<TestKeyboardOfficial> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  final ChatBottomPanelContainerController<PanelType> _panelController =
      ChatBottomPanelContainerController<PanelType>();

  PanelType _currentPanelType = PanelType.none;
  bool _readOnly = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// 更新输入框的 readOnly 状态
  bool _updateInputView({required bool isReadOnly}) {
    if (_readOnly != isReadOnly) {
      setState(() {
        _readOnly = isReadOnly;
      });
      return true;
    }
    return false;
  }

  /// 切换面板类型
  void _updatePanelType(PanelType type) {
    final isSwitchToKeyboard = type == PanelType.keyboard;
    final isSwitchToEmojiPanel = type == PanelType.emoji;
    bool isUpdated = false;

    switch (type) {
      case PanelType.keyboard:
        _updateInputView(isReadOnly: false);
        break;
      case PanelType.emoji:
      case PanelType.tool:
        isUpdated = _updateInputView(isReadOnly: true);
        break;
      default:
        break;
    }

    void updatePanelTypeFunc() {
      _panelController.updatePanelType(
        isSwitchToKeyboard
            ? ChatBottomPanelType.keyboard
            : ChatBottomPanelType.other,
        data: type,
        forceHandleFocus: isSwitchToEmojiPanel
            ? ChatBottomHandleFocus.requestFocus
            : ChatBottomHandleFocus.none,
      );
    }

    if (isUpdated) {
      // 等待输入框更新后再切换面板
      WidgetsBinding.instance.addPostFrameCallback((_) {
        updatePanelTypeFunc();
      });
    } else {
      updatePanelTypeFunc();
    }
  }

  /// 面板类型变化回调
  void _onPanelTypeChange(ChatBottomPanelType panelType, PanelType? data) {
    debugPrint('onPanelTypeChange: $panelType, data: $data');
    setState(() {
      switch (panelType) {
        case ChatBottomPanelType.none:
          _currentPanelType = PanelType.none;
          break;
        case ChatBottomPanelType.keyboard:
          _currentPanelType = PanelType.keyboard;
          break;
        case ChatBottomPanelType.other:
          if (data != null) {
            _currentPanelType = data;
          }
          break;
      }
    });
  }

  /// 输入框点击时的处理
  void _handleInputViewOnPointerUp() {
    if (_readOnly) {
      _updatePanelType(PanelType.keyboard);
    }
  }

  /// 表情按钮点击
  void _handleEmojiBtnClick() {
    _updatePanelType(
      _currentPanelType == PanelType.emoji
          ? PanelType.keyboard
          : PanelType.emoji,
    );
  }

  /// 工具按钮点击
  void _handleToolBtnClick() {
    _updatePanelType(
      _currentPanelType == PanelType.tool ? PanelType.keyboard : PanelType.tool,
    );
  }

  /// 构建面板内容
  Widget _buildPanelWidget(PanelType type) {
    final height = _panelController.keyboardHeight > 0
        ? _panelController.keyboardHeight
        : 300.0;

    switch (type) {
      case PanelType.none:
        return const SizedBox.shrink();
      case PanelType.keyboard:
        return const SizedBox.shrink();
      case PanelType.emoji:
        return Container(
          height: height,
          color: Colors.amber.shade100,
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 40,
            itemBuilder: (context, index) {
              final emojis = [
                '😀',
                '😁',
                '😂',
                '🤣',
                '😃',
                '😄',
                '😅',
                '😆',
                '😉',
                '😊',
                '😋',
                '😎',
                '😍',
                '😘',
                '🥰',
                '😗',
                '😙',
                '😚',
                '🙂',
                '🤗',
              ];
              return GestureDetector(
                onTap: () {
                  _textController.text += emojis[index % emojis.length];
                },
                child: Center(
                  child: Text(
                    emojis[index % emojis.length],
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              );
            },
          ),
        );
      case PanelType.tool:
        return Container(
          height: height,
          color: Colors.blue.shade100,
          child: GridView.count(
            crossAxisCount: 4,
            padding: const EdgeInsets.all(16),
            children: [
              _buildToolItem(Icons.image, '图片'),
              _buildToolItem(Icons.camera_alt, '拍照'),
              _buildToolItem(Icons.videocam, '视频'),
              _buildToolItem(Icons.location_on, '位置'),
              _buildToolItem(Icons.person, '名片'),
              _buildToolItem(Icons.folder, '文件'),
              _buildToolItem(Icons.favorite, '收藏'),
            ],
          ),
        );
    }
  }

  Widget _buildToolItem(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 28, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('官方 Demo 简化版')),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 30,
              itemBuilder: (context, index) {
                return ListTile(title: Text('消息 $index'));
              },
            ),
          ),

          // 输入栏
          Container(
            height: 50,
            color: Colors.white,
            child: Row(
              children: [
                const SizedBox(width: 15),
                // 输入框
                Expanded(
                  child: Listener(
                    onPointerUp: (_) => _handleInputViewOnPointerUp(),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      readOnly: _readOnly,
                      showCursor: true,
                      decoration: const InputDecoration(
                        hintText: '说点什么...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                // 表情按钮
                GestureDetector(
                  onTap: _handleEmojiBtnClick,
                  child: Icon(
                    Icons.emoji_emotions_outlined,
                    size: 30,
                    color: _currentPanelType == PanelType.emoji
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                // 工具按钮
                GestureDetector(
                  onTap: _handleToolBtnClick,
                  child: Icon(
                    Icons.add,
                    size: 30,
                    color: _currentPanelType == PanelType.tool
                        ? Colors.blue
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 15),
              ],
            ),
          ),

          // 底部面板容器
          ChatBottomPanelContainer<PanelType>(
            controller: _panelController,
            inputFocusNode: _focusNode,
            onPanelTypeChange: _onPanelTypeChange,
            panelBgColor: Colors.grey.shade100,
            otherPanelWidget: (type) {
              if (type == null) return const SizedBox.shrink();
              return _buildPanelWidget(type);
            },
          ),
        ],
      ),
    );
  }
}
