import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import '../models/chat_message.dart';

class ChatListWidget extends StatefulWidget {
  final ValueNotifier<List<ChatMessage>> messagesNotifier;

  const ChatListWidget({super.key, required this.messagesNotifier});

  @override
  State<ChatListWidget> createState() => _ChatListWidgetState();
}

class _ChatListWidgetState extends State<ChatListWidget> {
  final ScrollController _scrollController = ScrollController();
  late ListObserverController _observerController;

  int _unreadCount = 0;
  bool _isAtBottom = true;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _observerController = ListObserverController(controller: _scrollController);
    widget.messagesNotifier.value = [
      ChatMessage(
        sender: '系统',
        content: '欢迎来到直播间,禁止发布违法违规内容，文明发言',
        type: ChatMessageType.system,
      ),
    ];
    widget.messagesNotifier.addListener(_handleNewMessages);
  }

  @override
  void dispose() {
    widget.messagesNotifier.removeListener(_handleNewMessages);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleNewMessages() {
    if (_isAtBottom) {
      _scrollToBottom();
    } else {
      setState(() {
        _unreadCount++;
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    setState(() {
      _unreadCount = 0;
      _isAtBottom = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadHistory() async {
    if (_isLoadingHistory) return;
    setState(() => _isLoadingHistory = true);

    // 模拟网络延迟
    await Future.delayed(const Duration(seconds: 1));

    final history = List.generate(
      10,
      (i) => ChatMessage(
        sender: '历史用户',
        content: '这是历史消息 ${DateTime.now().millisecond + i}',
        type: ChatMessageType.user,
      ),
    );

    // 加载历史消息时不触发新消息通知
    widget.messagesNotifier.removeListener(_handleNewMessages);
    final currentMessages = widget.messagesNotifier.value;
    widget.messagesNotifier.value = [...history, ...currentMessages];
    widget.messagesNotifier.addListener(_handleNewMessages);

    if (mounted) {
      setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black],
              stops: [0.0, 0.1, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListViewObserver(
            controller: _observerController,
            onObserve: (result) {
              // 某些版本可能需要通过 result 来判断是否到底部
              // 这里简化处理：通过 ScrollController 的位置判断
            },
            child: ValueListenableBuilder<List<ChatMessage>>(
              valueListenable: widget.messagesNotifier,
              builder: (context, messages, child) {
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      final metrics = notification.metrics;
                      final isAtBottom =
                          metrics.pixels >= metrics.maxScrollExtent - 20;

                      if (isAtBottom != _isAtBottom) {
                        setState(() {
                          _isAtBottom = isAtBottom;
                          if (isAtBottom) _unreadCount = 0;
                        });
                      }

                      // 检测是否滚动到顶部加载历史
                      if (metrics.pixels <= 0 && !_isLoadingHistory) {
                        _loadHistory();
                      }
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 40, bottom: 8),
                    itemCount: messages.length + (_isLoadingHistory ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoadingHistory && index == 0) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CupertinoActivityIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }

                      final msgIndex = _isLoadingHistory ? index - 1 : index;
                      final msg = messages[msgIndex];

                      if (msg.type == ChatMessageType.system) {
                        return _buildSystemMessage(msg);
                      }
                      return _buildUserMessage(msg);
                    },
                  ),
                );
              },
            ),
          ),
        ),
        if (_unreadCount > 0)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '新 $_unreadCount 条消息',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSystemMessage(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          // 玻璃效果
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          msg.content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            shadows: [Shadow(blurRadius: 2, color: Colors.black26)],
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessage(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          // 玻璃效果
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${msg.sender}: ',
                style: const TextStyle(
                  color: Color(0xFFADD8E6), // 浅蓝色用户名
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              TextSpan(
                text: msg.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
