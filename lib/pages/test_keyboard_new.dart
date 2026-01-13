/// 使用 ChatPanelController + AnimatedChatPanel 的测试页面
/// 使用 StatefulWidget 确保正确的生命周期管理
import 'package:flutter/material.dart';
import 'package:live_app/widgets/chat_panel_controller.dart';
import 'package:live_app/widgets/animated_chat_panel.dart';
import 'package:live_app/utils/text_measure.dart';

class TestKeyboardNew extends StatefulWidget {
  const TestKeyboardNew({super.key});

  @override
  State<TestKeyboardNew> createState() => _TestKeyboardNewState();
}

class _TestKeyboardNewState extends State<TestKeyboardNew> {
  final _textController = TextEditingController();
  final _chatController = ChatPanelController();
  AnimationType _animationType = AnimationType.fade;

  @override
  void initState() {
    super.initState();
    _chatController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _chatController.removeListener(_onControllerChanged);
    _chatController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// 插入表情到光标位置，并滚动确保光标可见
  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final cursorPos = selection.baseOffset >= 0
        ? selection.baseOffset
        : text.length;
    final isAtEnd = cursorPos >= text.length;

    // 在光标位置插入表情
    final newText =
        text.substring(0, cursorPos) + emoji + text.substring(cursorPos);

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + emoji.length),
    );

    // 滚动确保光标可见
    final sc = _chatController.scrollController;
    Future.delayed(const Duration(milliseconds: 50), () {
      if (sc.hasClients) {
        if (isAtEnd) {
          // 末尾插入：滚动到最大位置
          sc.jumpTo(sc.position.maxScrollExtent);
        } else {
          // 中间插入：滚动当前位置 + 表情宽度
          final emojiWidth = TextMeasure.measureEmojiWidth(emoji);
          final newOffset = (sc.offset + emojiWidth).clamp(
            0.0,
            sc.position.maxScrollExtent,
          );
          sc.jumpTo(newOffset);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('新版键盘测试'),
        actions: [
          PopupMenuButton<AnimationType>(
            icon: const Icon(Icons.animation),
            tooltip: '选择动画',
            onSelected: (type) => setState(() => _animationType = type),
            itemBuilder: (context) => AnimationType.values.map((type) {
              return PopupMenuItem(
                value: type,
                child: Row(
                  children: [
                    if (type == _animationType)
                      const Icon(Icons.check, size: 18),
                    if (type != _animationType) const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(_getAnimationName(type)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 动画类型提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Text(
              '当前动画: ${_getAnimationName(_animationType)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blue, fontSize: 13),
            ),
          ),

          // 消息列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 30,
              itemBuilder: (context, index) =>
                  ListTile(title: Text('消息 $index')),
            ),
          ),

          // 输入栏
          Container(
            height: 50,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: Listener(
                    // onPointerUp: (_) => _chatController.handleInputTap(),
                    child: TextField(
                      controller: _textController,
                      focusNode: _chatController.focusNode,
                      scrollController: _chatController.scrollController,
                      readOnly: _chatController.readOnly,
                      showCursor: true,
                      decoration: const InputDecoration(
                        hintText: '说点什么...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _chatController.toggleEmoji,
                  child: Icon(
                    Icons.emoji_emotions_outlined,
                    size: 28,
                    color:
                        _chatController.currentPanelType == ChatPanelType.emoji
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _chatController.toggleTool,
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 28,
                    color:
                        _chatController.currentPanelType == ChatPanelType.tool
                        ? Colors.blue
                        : Colors.grey,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _chatController.close();
                  },
                  icon: const Icon(Icons.close, size: 28, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 底部面板
          AnimatedChatPanel(
            controller: _chatController,
            animationType: _animationType,
            panelBuilder: _buildPanel,
          ),
        ],
      ),
    );
  }

  String _getAnimationName(AnimationType type) {
    const names = {
      AnimationType.none: '无动画',
      AnimationType.fade: '淡入淡出',
      AnimationType.flipX: '水平翻转',
      AnimationType.flipY: '垂直翻转',
      AnimationType.slideUp: '向上滑动',
      AnimationType.slideDown: '向下滑动',
      AnimationType.slideLeft: '向左滑动',
      AnimationType.slideRight: '向右滑动',
      AnimationType.zoomIn: '放大进入',
      AnimationType.zoomOut: '缩小进入',
    };
    return names[type] ?? type.name;
  }

  Widget _buildPanel(ChatPanelType type, double height) {
    switch (type) {
      case ChatPanelType.none:
      case ChatPanelType.keyboard:
        return const SizedBox.shrink();
      case ChatPanelType.emoji:
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
        return Container(
          height: height,
          color: Colors.amber.shade50,
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 40,
            itemBuilder: (context, index) {
              final emoji = emojis[index % emojis.length];
              return GestureDetector(
                onTap: () => _insertEmoji(emoji),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        );
      case ChatPanelType.tool:
        return Container(
          height: height,
          color: Colors.blue.shade50,
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
}
