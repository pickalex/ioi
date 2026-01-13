import 'package:flutter/material.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import '../models/chat_message.dart';
import '../widgets/chat_panel_controller.dart';
import '../widgets/animated_chat_panel.dart';
import '../widgets/interactive_widgets.dart';
import '../widgets/friend_chat_input_area.dart';
import '../widgets/chat_message_bubble.dart';
import 'dart:convert';
import 'dart:async';
import '../services/agora_service.dart';
import '../services/user_service.dart';
import 'package:agora_rtm/agora_rtm.dart' as rtm;

class FriendChatPage extends StatefulWidget {
  final String friendId;
  final String friendName;
  const FriendChatPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<FriendChatPage> createState() => _FriendChatPageState();
}

class _FriendChatPageState extends State<FriendChatPage> {
  final TextEditingController _messageController = TextEditingController();
  late ChatPanelController _panelController;
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingHistory = false;
  bool _hasMoreHistory = true; // For demonstration

  late SliverObserverController _observerController;

  // centerKey for stable scrolling
  final GlobalKey _centerKey = GlobalKey();

  // historyMessages will go "up" (before center)
  final List<ChatMessage> _historyMessages = [];
  // newMessages will go "down" (after center, inclusive)
  final List<ChatMessage> _newMessages = [
    ChatMessage(sender: 'System', content: 'Chat started'),
  ];

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _panelController = ChatPanelController();
    _observerController = SliverObserverController();
    // Large initial preload (30 messages)
    _loadHistory(count: 30);

    // Initialize RTM Inbox Subscription
    final myId = userService.currentUser?.id;
    if (myId != null) {
      AgoraService().subscribeToInbox(myId);
    }

    // Listen for incoming messages
    _messageSubscription = AgoraService().messageStream.listen((event) {
      // In production, we should filter by publisherId or channel
      // But for RTM 2.x Inbox, we receive messages sent to our inbox channel.
      // We assume if we are in this page, we show messages from this friend
      // OR we just append all for demo.
      // Ideally check: if event.publisherId == widget.friendId (needs publisherId fix in AgoraService first or use parsing)

      // Simply append for now to demonstrate receipt
      if (mounted) {
        setState(() {
          // Message data is Uint8List? or String?
          // Depending on how AgoraService exposes it.
          // Previous edit used `event.message?.data` which is Uint8List generally.
          // sendPeerMessage sends string. RTM 2.x handles string payload.
          // We'll safely decode.

          String content = '[Image/Other]';
          if (event.message != null) {
            try {
              // event.message is Uint8List
              content = utf8.decode(event.message!);
            } catch (_) {
              content = '[Binary Data]';
            }
          }

          _newMessages.add(
            ChatMessage(sender: widget.friendName, content: content),
          );
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({int count = 10}) async {
    if (_isLoadingHistory || !_hasMoreHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() {
      final List<ChatMessage> older = List.generate(
        count,
        (index) => ChatMessage(
          sender: widget.friendName,
          content: 'Historical message ${_historyMessages.length + index + 1}',
        ),
      );

      _historyMessages.addAll(older);
      _isLoadingHistory = false;

      // Stop after 100 messages for demo
      if (_historyMessages.length >= 100) {
        _hasMoreHistory = false;
      }
    });
    debugPrint('Loaded history: total ${_historyMessages.length} messages');
  }

  void _onSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Send via RTM
    AgoraService().sendPeerMessage(widget.friendId, text);

    setState(() {
      _newMessages.add(ChatMessage(sender: 'Me', content: text));
      _messageController.clear();
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onSelectEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(
      selection.start >= 0 ? selection.start : text.length,
      selection.end >= 0 ? selection.end : text.length,
      emoji,
    );
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset:
            (selection.start >= 0 ? selection.start : text.length) +
            emoji.length,
      ),
    );

    // Scroll TextField to the end if content is too long
    final sc = _panelController.scrollController;
    Future.delayed(const Duration(milliseconds: 50), () {
      if (sc.hasClients) {
        sc.animateTo(
          sc.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onToggleEmoji() {
    _panelController.toggleEmoji();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _panelController.hidePanel();
              },
              child: SliverViewObserver(
                controller: _observerController,
                onObserve: (result) {
                  if (result is ListViewObserveModel) {
                    final visibleIndices = result.displayingChildIndexList;
                    if (visibleIndices.isEmpty) return;

                    final maxVisibleIndex = visibleIndices.reduce(
                      (a, b) => a > b ? a : b,
                    );
                    final totalCount = _historyMessages.length;

                    // Trigger when reaching the top 5 oldest messages
                    if (totalCount > 0 && maxVisibleIndex >= totalCount - 5) {
                      debugPrint(
                        'Observer trigger: visible indices $visibleIndices, total $totalCount. Loading more...',
                      );
                      _loadHistory();
                    }
                  }
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  center: _centerKey,
                  reverse: false,
                  slivers: [
                    // historyMessages go up (prepended)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return ChatMessageBubble(
                          message: _historyMessages[index],
                          isMe: _historyMessages[index].sender == 'Me',
                        );
                      }, childCount: _historyMessages.length),
                    ),
                    // newMessages go down (appended)
                    SliverList(
                      key: _centerKey,
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return ChatMessageBubble(
                          message: _newMessages[index],
                          isMe: _newMessages[index].sender == 'Me',
                        );
                      }, childCount: _newMessages.length),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _panelController,
            builder: (context, _) {
              return FriendChatInputArea(
                messageController: _messageController,
                panelController: _panelController,
                onSend: _onSend,
                onToggleEmoji: _onToggleEmoji,
              );
            },
          ),
          AnimatedChatPanel(
            controller: _panelController,
            animationType: AnimationType.fade,
            panelBuilder: (type, height) {
              if (type == ChatPanelType.emoji) {
                return EmojiPickerContent(
                  controller: _panelController.panelController,
                  height: height,
                  width: double.infinity,
                  onSelected: _onSelectEmoji,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
