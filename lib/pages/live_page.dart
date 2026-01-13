import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import '../services/agora_service.dart';
import '../services/presence_service.dart';
import '../services/user_service.dart';
import '../models/chat_message.dart';
import 'dart:async';
import 'dart:convert';
import '../widgets/gift_overlay.dart';
import '../widgets/interactive_widgets.dart';
import '../widgets/cupertino_popover.dart';
import '../widgets/live_chat_list.dart';
import '../widgets/chat_panel_controller.dart';
import '../widgets/animated_chat_panel.dart';
import '../utils/text_measure.dart';
import '../widgets/sports_player_overlay.dart';
import 'landscape_player_page.dart';
import 'package:flutter/services.dart';

class LivePage extends StatefulWidget {
  final String channelName;
  final ClientRoleType role;
  final String? playbackUrl;

  const LivePage({
    super.key,
    required this.channelName,
    required this.role,
    this.playbackUrl,
  });

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage>
    with SingleTickerProviderStateMixin {
  // region Fields
  final _agoraService = AgoraService();
  final List<int> _remoteUids = [];
  late ClientRoleType _currentRole;

  // Chat
  final ValueNotifier<List<ChatMessage>> _messagesNotifier = ValueNotifier([]);
  final TextEditingController _messageController = TextEditingController();
  late ChatPanelController _panelController;
  Timer? _mockJoinTimer;
  final List<StreamSubscription> _subscriptions = [];

  // Gift
  final StreamController<GiftAnimation> _giftStreamController =
      StreamController<GiftAnimation>.broadcast();

  // Video Controllers
  VideoViewController? _localController;
  VideoViewControllerBase? _mediaPlayerController;
  final Map<int, VideoViewController> _remoteControllers = {};

  // Loading state
  bool _isLoading = true; // 显示加载中，等待主播连接

  // Room entry notification
  String? _entryNotification;
  Timer? _entryTimer;

  // Broadcaster controls
  bool _isFrontCamera = true;
  double _zoomFactor = 1.0;
  bool _isLocalVideoEnabled = true;
  String _currentQuality = '720P';
  bool _isScreenSharing = false;
  bool _isMediaPlayerPlaying = false;

  // Player Sync & Overlay
  Duration _mediaDuration = Duration.zero;
  Duration _mediaPosition = Duration.zero;
  bool _isOverlayVisible = false;
  Timer? _overlayTimer;
  Timer? _syncTimer; // Broadcaster only: sends sync heartbeat
  bool _isLiveSync = true; // Audience only: follow broadcaster?
  String? _currentMediaUrl;

  // PiP Window State
  Offset? _pipPosition;
  bool _isPipVisible = true;
  // endregion

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    _initAgora();
    _panelController = ChatPanelController();
  }

  @override
  void dispose() {
    // 如果是主播，取消直播状态
    if (widget.role == ClientRoleType.clientRoleBroadcaster) {
      presenceService.setLiveStatus(isLive: false);
    }

    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _mockJoinTimer?.cancel();
    _messageController.dispose();
    _panelController.dispose();
    _messagesNotifier.dispose();
    _giftStreamController.close();
    _localController?.dispose();
    _mediaPlayerController?.dispose();
    for (var controller in _remoteControllers.values) {
      controller.dispose();
    }
    _agoraService.leaveChannel();
    _agoraService.release();
    super.dispose();
  }

  // region Initialization
  Future<void> _initAgora() async {
    await _agoraService.initRtc();

    // 初始化 RTM (聊天和状态同步需要)
    // CRITICAL: Ensure unique RTM ID per session to support multiple devices on the same account
    final baseId = userService.currentUser?.id ?? 'guest';
    final sessionId = DateTime.now().millisecondsSinceEpoch % 10000;
    final userId = "${baseId}_$sessionId";
    await _agoraService.initRtm(userId);

    // 初始化 Presence 服务（在 RTM 登录后）
    await presenceService.init();

    // 如果是主播，发布直播状态 (Ensure RTM is ready first)
    if (widget.role == ClientRoleType.clientRoleBroadcaster) {
      presenceService.setLiveStatus(isLive: true, roomId: widget.channelName);
    }

    // Subscribe to events
    _subscriptions.add(
      _agoraService.connectionStream.listen((connection) {
        if (mounted) {
          setState(() => _isLoading = false); // 连接成功，停止加载
        }
      }),
    );
    _subscriptions.add(
      _agoraService.logStream.listen((log) {
        debugPrint('📡 Agora: $log');
      }),
    );
    _subscriptions.add(
      _agoraService.userJoinedStream.listen((uid) {
        if (mounted) {
          setState(() => _remoteUids.add(uid));
          _showEntryNotification('用户 $uid');
        }
      }),
    );
    _subscriptions.add(
      _agoraService.userOfflineStream.listen((uid) {
        if (mounted) {
          setState(() {
            _remoteUids.remove(uid);
            final controller = _remoteControllers.remove(uid);
            controller?.dispose();
          });
        }
      }),
    );

    _subscriptions.add(
      _agoraService.playerStateStream.listen((state) {
        if (mounted) {
          if (state == MediaPlayerState.playerStateOpenCompleted ||
              state == MediaPlayerState.playerStatePlaying) {
            _onMediaPlayerStateChanged(true);
          } else if (state == MediaPlayerState.playerStatePlaybackCompleted ||
              state == MediaPlayerState.playerStateStopped) {
            _onMediaPlayerStateChanged(false);
          }
        }
      }),
    );
    _subscriptions.add(
      _agoraService.playerStateStream.listen((state) {
        if (mounted) {
          if (state == MediaPlayerState.playerStateOpenCompleted ||
              state == MediaPlayerState.playerStatePlaying) {
            _onMediaPlayerStateChanged(true);
          } else if (state == MediaPlayerState.playerStatePlaybackCompleted ||
              state == MediaPlayerState.playerStateStopped) {
            _onMediaPlayerStateChanged(false);
          }
        }
      }),
    );

    _subscriptions.add(
      _agoraService.activeSourceStream.listen((source) {
        if (mounted) {
          setState(() {}); // 重绘以更新切换按钮状态
        }
      }),
    );

    // 如果有 Playback URL，优先进入回放模式 (不进入 RTC 频道，只播放媒体)
    if (widget.playbackUrl != null) {
      await _agoraService.startMediaPlayer(widget.playbackUrl!, publish: false);
      return;
    }

    await _agoraService.joinChannel(
      channelId: widget.channelName,
      role: _currentRole,
    );

    // 初始化本地视频控制器
    if (_currentRole == ClientRoleType.clientRoleBroadcaster) {
      _localController = VideoViewController(
        rtcEngine: _agoraService.engine,
        canvas: const VideoCanvas(uid: 0),
      );
    }

    // 超时后停止加载显示（如果没有主播在线）
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    _initRtm();
  }

  Future<void> _initRtm() async {
    // Check if RTM is logged in before accessing rtmClient
    if (!_agoraService.isRtmLoggedIn) {
      debugPrint("Warning: RTM not logged in, skipping LivePage RTM init");
      return;
    }

    try {
      // 已经在 _initAgora 中调用了 _agoraService.initRtm()
      // 这里只需要订阅频道

      // 1. Register RTM Event Listener
      _agoraService.rtmClient.addListener(
        message: (event) {
          // RTM 2.x MessageEvent - message is Uint8List, need to decode
          debugPrint("RTM Message received from: ${event.publisher}");
          final sender = event.publisher ?? '匿名';
          // Convert Uint8List to String using UTF-8 for emoji support
          String content = '';
          if (event.message != null) {
            try {
              content = utf8.decode(event.message!);
            } catch (e) {
              content = String.fromCharCodes(event.message!);
            }
          }
          debugPrint("RTM Message content: $content");
          // 不显示自己发送的消息（已经在 _submitMessage 中添加了）
          _addMessage(
            ChatMessage(
              sender: sender,
              content: content,
              type: ChatMessageType.user,
            ),
          );
        },
      );

      // 2. Subscribe to Channel
      final (status, _) = await _agoraService.rtmClient.subscribe(
        widget.channelName,
      );
      if (status.error) {
        debugPrint("RTM Subscribe error: ${status.reason}");
      } else {
        debugPrint("RTM Subscribed to: ${widget.channelName}");
        _addMessage(
          ChatMessage(
            sender: '系统',
            content: '已连接到聊天服务器',
            type: ChatMessageType.system,
          ),
        );
      }
    } catch (e) {
      debugPrint("RTM Init Error: $e");
    }
  }

  void _submitMessage(String value) async {
    final text = value.trim();
    if (text.isEmpty) return;

    // Check if RTM is connected
    if (!_agoraService.isRtmLoggedIn) {
      SmartDialog.showToast('聊天服务未连接，请稍后重试');
      debugPrint("RTM not logged in, cannot send message");
      return;
    }

    try {
      // 发送 RTM 消息
      debugPrint("RTM Publish to: ${widget.channelName}, message: $text");

      final result = await _agoraService.rtmClient.publish(
        widget.channelName,
        text,
      );

      final (status, _) = result;

      if (status.error) {
        debugPrint("RTM Publish error: ${status.reason}");
        SmartDialog.showToast('发送失败: ${status.reason}');
      } else {
        debugPrint("RTM Publish success");
        // 监听频道消息 (Sync Logic)
        _agoraService.messageStream.listen((msg) async {
          if (widget.role == ClientRoleType.clientRoleBroadcaster)
            return; // Ignore own messages

          try {
            final String decodedMsg = utf8.decode(msg.message!);
            final Map<String, dynamic> data = jsonDecode(decodedMsg);
            if (data['type'] == 'sync') {
              final int remotePos = data['pos'];
              final String url = data['url'];
              final int duration = data['duration'];

              // Update duration if needed
              if (_mediaDuration.inMilliseconds != duration) {
                setState(
                  () => _mediaDuration = Duration(milliseconds: duration),
                );
              }

              // If not playing, start playing
              if (!_isMediaPlayerPlaying && url.isNotEmpty) {
                if (_currentMediaUrl != url) {
                  _currentMediaUrl = url;
                  await _agoraService.startMediaPlayer(url);
                  // Mute audio if needed to avoid echo? usually audience wants audio
                  // Sync to position
                  await _agoraService.mediaPlayer?.seek(remotePos);
                  setState(() => _isMediaPlayerPlaying = true);
                }
              }

              // Live Sync Match
              if (_isLiveSync && _isMediaPlayerPlaying) {
                final currentPos =
                    await _agoraService.mediaPlayer?.getPlayPosition() ?? 0;
                if ((currentPos - remotePos).abs() > 2000) {
                  // Drift > 2s, force sync
                  await _agoraService.mediaPlayer?.seek(
                    remotePos + 200,
                  ); // Add RTT buffer
                }
              }
            }
          } catch (e) {
            // efficient fail
          }
        });
        if (mounted) {
          _addMessage(ChatMessage(sender: '我', content: text));
          _messageController.clear();
        }
      }
    } catch (e) {
      debugPrint("RTM Publish exception: $e");
      if (mounted) SmartDialog.showToast('发送失败: $e');
    }
  }

  // endregion

  // region Keyboard/Panel Configuration

  void _onToggleEmoji() {
    _panelController.toggleEmoji();
  }

  void _showEntryNotification(String userName) {
    _entryTimer?.cancel();
    setState(() {
      _entryNotification = '$userName 进入直播间';
    });
    _entryTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _entryNotification = null);
      }
    });
  }
  // endregion

  // region Business Logic
  void _onSwitchRole() async {
    final nextRole = _currentRole == ClientRoleType.clientRoleBroadcaster
        ? ClientRoleType.clientRoleAudience
        : ClientRoleType.clientRoleBroadcaster;

    await _agoraService.switchRole(nextRole);
    setState(() => _currentRole = nextRole);
  }

  void _sendGift(Gift gift) {
    _addMessage(
      ChatMessage(
        sender: '系统',
        content: '我 送出了 ${gift.emoji} ${gift.name}',
        type: ChatMessageType.system,
      ),
    );
    _giftStreamController.add(
      GiftAnimation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        giftName: gift.name,
        emoji: gift.emoji,
        sender: '我',
      ),
    );
  }

  void _addMessage(ChatMessage message) {
    if (!mounted) return;
    _messagesNotifier.value = [..._messagesNotifier.value, message];
  }

  void _onToggleCamera() async {
    await _agoraService.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  void _onToggleVideo() async {
    final nextState = !_isLocalVideoEnabled;
    await _agoraService.setLocalVideoEnabled(nextState);
    setState(() => _isLocalVideoEnabled = nextState);
    SmartDialog.showToast(nextState ? '摄像头已开启' : '摄像头已关闭');
  }

  void _onToggleScreenShare() async {
    if (_isScreenSharing) {
      await _agoraService.stopScreenShare();
      setState(() => _isScreenSharing = false);
      SmartDialog.showToast('屏幕共享已停止');
    } else {
      // 如果正在播放视频，先停止
      if (_isMediaPlayerPlaying) {
        await _agoraService.stopMediaPlayer();
        setState(() => _isMediaPlayerPlaying = false);
      }
      await _agoraService.startScreenShare();
      setState(() => _isScreenSharing = true);
      SmartDialog.showToast('屏幕共享已启动');
    }
  }

  void _onSwitchSource() async {
    if (_agoraService.activeSource == AgoraVideoSource.camera) {
      if (_isMediaPlayerPlaying) {
        await _agoraService.setActiveSource(AgoraVideoSource.mediaPlayer);
        SmartDialog.showToast('已切换至视频画面给观众');
      } else {
        SmartDialog.showToast('请先开始推送视频');
      }
    } else {
      await _agoraService.setActiveSource(AgoraVideoSource.camera);
      SmartDialog.showToast('已切换回摄像头画面给观众');
    }
    setState(() {});
  }

  void _onToggleMediaPlayer() async {
    if (_isMediaPlayerPlaying) {
      await _agoraService.stopMediaPlayer();
      _onMediaPlayerStateChanged(false);
      SmartDialog.showToast('视频推送已停止');
    } else {
      _showUrlInputDialog();
    }
  }

  void _onMediaPlayerStateChanged(bool isPlaying) {
    if (isPlaying) {
      if (_mediaPlayerController == null && _agoraService.mediaPlayer != null) {
        // 使用标准的 VideoViewController 渲染 MediaPlayer，这种方式最稳，避免了 MediaPlayerController 的类型转换 Bug
        _mediaPlayerController = VideoViewController(
          rtcEngine: _agoraService.engine,
          canvas: VideoCanvas(
            uid: _agoraService.mediaPlayer!.getMediaPlayerId(),
            sourceType: VideoSourceType.videoSourceMediaPlayer,
          ),
          useFlutterTexture: true,
        );
      }
    } else {
      _mediaPlayerController?.dispose();
      _mediaPlayerController = null;
    }
    setState(() {
      _isMediaPlayerPlaying = isPlaying;
      if (isPlaying) {
        // Reset PiP state when starting playback
        _isPipVisible = true;
        _pipPosition = null;
      }
    });
  }

  void _showUrlInputDialog() {
    final urlController = TextEditingController(
      text: 'https://vjs.zencdn.net/v/oceans.mp4',
    );
    SmartDialog.show(
      builder: (_) => Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '推送在线视频',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '输入视频 URL',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '快速测试:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSampleChip(
                  '浙江卫视',
                  'https://v-cdn.zjol.com.cn/280443.mp4',
                  urlController,
                ),
                _buildSampleChip(
                  '今日体育',
                  'https://v-cdn.zjol.com.cn/276982.mp4',
                  urlController,
                ),
                _buildSampleChip(
                  '今日头条',
                  'https://v-cdn.zjol.com.cn/276984.mp4',
                  urlController,
                ),
                _buildSampleChip(
                  '海洋(Global)',
                  'https://vjs.zencdn.net/v/oceans.mp4',
                  urlController,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => SmartDialog.dismiss(),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final url = urlController.text.trim();
                    if (url.isEmpty) return;
                    SmartDialog.dismiss();

                    // 如果正在共享屏幕，先停止
                    if (_isScreenSharing) {
                      await _agoraService.stopScreenShare();
                      setState(() => _isScreenSharing = false);
                    }

                    await _agoraService.startMediaPlayer(url);
                    setState(() {
                      _currentMediaUrl = url;
                    });

                    // Start Sync Timer (Broadcaster)
                    _startBroadcasterSync();
                    // 不再手动调用 _onMediaPlayerStateChanged，等待 playerStateStream 的回调
                    SmartDialog.showToast('正在开始推送视频...');
                  },
                  child: const Text('开始推送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleChip(
    String label,
    String url,
    TextEditingController controller,
  ) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: Colors.blue.withOpacity(0.2),
      onPressed: () => controller.text = url,
    );
  }

  void _onZoomChanged(double value) async {
    await _agoraService.setCameraZoomFactor(value);
    setState(() => _zoomFactor = value);
  }

  void _onSelectQuality() {
    SmartDialog.show(
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择画质',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildQualityOption('1080P', VideoQuality.fhd_1080p, 30),
            _buildQualityOption('720P', VideoQuality.hd_720p, 30),
            _buildQualityOption('480P', VideoQuality.hd_480p, 15),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(String label, VideoQuality quality, int fps) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: _currentQuality == label
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        _agoraService.setVideoQuality(quality, frameRate: fps);
        setState(() => _currentQuality = label);
        SmartDialog.dismiss();
        SmartDialog.showToast('已切换至 $label');
      },
    );
  }
  // endregion

  // region Build
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        return Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false, // Required by chat_bottom_container
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // 视频区域（点击收起键盘）
                    GestureDetector(
                      onTap: () {
                        _panelController.hidePanel();
                      },
                      child: Stack(
                        children: [
                          _viewRows(),
                          // Sports Overlay
                          if (_isOverlayVisible)
                            Positioned.fill(
                              child: SportsPlayerOverlay(
                                totalDuration: _mediaDuration,
                                currentPosition: _mediaPosition,
                                isLive: _isLiveSync,
                                onSeek: (pos) {
                                  _seekTo(pos);
                                  setState(() => _isLiveSync = false);
                                },
                                onToggleFullscreen: _navigateToLandscape,
                                isLandscape: isLandscape,
                                onGoLive: () {
                                  setState(() => _isLiveSync = true);
                                },
                              ),
                            ),
                          // Tap to toggle overlay
                          if (!_isOverlayVisible)
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: _toggleOverlay,
                                behavior: HitTestBehavior.translucent,
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Gift animations
                    Positioned.fill(
                      bottom: isLandscape ? 100 : 250,
                      child: GiftOverlay.slideLeft(
                        giftStream: _giftStreamController.stream,
                      ),
                    ),
                    // 主播控制面板
                    if (_currentRole == ClientRoleType.clientRoleBroadcaster)
                      Positioned(
                        top: isLandscape
                            ? 16
                            : MediaQuery.of(context).padding.top + 60,
                        right: 16,
                        child: _buildBroadcasterControls(isLandscape),
                      ),
                    // 输入区域（在视频上层）
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 聊天列表（在输入框上方）
                          SizedBox(
                            height: isLandscape ? 120 : 200,
                            width:
                                MediaQuery.of(context).size.width *
                                (isLandscape ? 0.4 : 0.7),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: ChatListWidget(
                                messagesNotifier: _messagesNotifier,
                              ),
                            ),
                          ),
                          // 进入直播间通知
                          if (_entryNotification != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                bottom: 4,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _entryNotification!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          // 输入框区域
                          _buildBottomArea(isLandscape),
                        ],
                      ),
                    ),
                    // 横屏模式下的退出按钮（因为没用AppBar）
                    if (isLandscape)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: SafeArea(
                          child: RawMaterialButton(
                            onPressed: () => context.pop(),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            shape: const CircleBorder(),
                            fillColor: Colors.black38,
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 键盘/表情面板区域
              AnimatedChatPanel(
                controller: _panelController,
                animationType: AnimationType.fade,
                panelBgColor: const Color(0xFF1A1A1A),
                panelBuilder: (type, height) {
                  if (type == ChatPanelType.emoji) {
                    return EmojiPickerContent(
                      controller: _panelController.panelController,
                      height: height,
                      width: double.infinity,
                      onSelected: _insertEmoji,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomArea(bool isLandscape) {
    return Container(
      padding: EdgeInsets.only(
        bottom: (isLandscape ? 8 : MediaQuery.of(context).padding.bottom) + 8,
        top: 8,
      ),
      decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListenableBuilder(
              listenable: _panelController,
              builder: (context, boxConstraints) {
                final isInputActive =
                    _panelController.focusNode.hasFocus ||
                    _panelController.readOnly;

                return Row(
                  children: [
                    Expanded(child: _buildEntryInput()),
                    const SizedBox(width: 12),
                    if (isInputActive)
                      GestureDetector(
                        onTap: () => _submitMessage(_messageController.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D4D),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Text(
                            '发送',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      _toolbarButtons(),
                  ],
                );
              },
            ),
          ),
          ListenableBuilder(
            listenable: _panelController,
            builder: (context, _) {
              final hasPanel =
                  _panelController.currentPanelType != ChatPanelType.none;
              final hasFocus = _panelController.focusNode.hasFocus;
              if (!hasFocus && !hasPanel) return const SizedBox.shrink();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: HorizontalEmojiPicker(onSelected: _insertEmoji),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 插入表情到光标位置
  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursorPos = selection.baseOffset;
    final isAtEnd = cursorPos >= text.length;

    final newText =
        text.substring(0, cursorPos) + emoji + text.substring(cursorPos);

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + emoji.length),
    );

    // 手动滚动确保光标可见
    final sc = _panelController.scrollController;
    Future.delayed(const Duration(milliseconds: 50), () {
      if (sc.hasClients) {
        if (isAtEnd) {
          sc.jumpTo(sc.position.maxScrollExtent);
        } else {
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

  Widget _buildEntryInput() {
    return ListenableBuilder(
      listenable: _panelController,
      builder: (context, child) {
        return IgnorePointer(
          ignoring: _isLoading,
          child: Opacity(
            opacity: _isLoading ? 0.5 : 1.0,
            child: GestureDetector(
              onTap: _panelController.handleInputTap,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _panelController.focusNode,
                        scrollController: _panelController.scrollController,
                        readOnly: _panelController.readOnly,
                        showCursor: true,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: '说点什么...',
                          hintStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: IconButton(
                            onPressed: _onToggleEmoji,
                            icon: Icon(
                              Icons.sentiment_satisfied_alt_outlined,
                              color:
                                  (_panelController.focusNode.hasFocus ||
                                      _panelController.readOnly)
                                  ? const Color(0xFFFF4D4D)
                                  : Colors.white70,
                              size: 24,
                            ),
                          ),
                        ),
                        onSubmitted: _submitMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _viewRows() {
    final List<Widget> list = [];

    if (_currentRole == ClientRoleType.clientRoleBroadcaster) {
      if (_isMediaPlayerPlaying) {
        // 主视角：媒体播放器
        if (_mediaPlayerController != null) {
          list.add(
            AgoraVideoView(
              key: ValueKey(
                'media_player_view_${_agoraService.mediaPlayer?.getMediaPlayerId()}',
              ),
              controller: _mediaPlayerController!,
            ),
          );
        } else {
          // 如果控制器还没准备好，显示黑色背景
          list.add(Container(color: Colors.black));
        }
        // 画中画：本地摄像头
        if (_localController != null && _isPipVisible) {
          // Calculate default position if not set
          if (_pipPosition == null) {
            final size = MediaQuery.of(context).size;
            // Default to bottom-right, roughly where it was
            _pipPosition = Offset(
              size.width - 120 - 16,
              size.height - 350 - 180,
            );
          }

          list.add(
            Positioned(
              left: _pipPosition!.dx,
              top: _pipPosition!.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _pipPosition = _pipPosition! + details.delta;
                  });
                },
                child: SizedBox(
                  width: 120,
                  height: 180,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 1),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors
                              .black54, // Slight background for better visibility
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AgoraVideoView(
                            key: const ValueKey('local_view_pip'),
                            controller: _localController!,
                          ),
                        ),
                      ),
                      // Close Button
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _isPipVisible = false),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      } else {
        // 主视角：本地摄像头
        if (_localController != null) {
          list.add(
            AgoraVideoView(
              key: const ValueKey('local_view_main'),
              controller: _localController!,
            ),
          );
        }

        // 如果播放器在后台播放，主播端也可以选择看到小窗（可选实现，这里暂时不加小窗）
      }
    } else {
      // 观众端逻辑

      // 1. 如果是回放模式
      if (widget.playbackUrl != null && _isMediaPlayerPlaying) {
        if (_mediaPlayerController != null) {
          list.add(
            AgoraVideoView(
              key: ValueKey(
                'playback_view_${_agoraService.mediaPlayer?.getMediaPlayerId()}',
              ),
              controller: _mediaPlayerController!,
            ),
          );
        } else {
          list.add(
            const Center(
              child: CupertinoActivityIndicator(color: Colors.white),
            ),
          );
        }
      }
      // 2. 普通直播模式
      else if (_remoteUids.isNotEmpty) {
        for (var uid in _remoteUids) {
          final controller = _remoteControllers.putIfAbsent(
            uid,
            () => VideoViewController.remote(
              rtcEngine: _agoraService.engine,
              canvas: VideoCanvas(uid: uid),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          );
          list.add(
            AgoraVideoView(
              key: ValueKey('remote_view_$uid'),
              controller: controller,
            ),
          );
        }
      }
    }

    if (list.isEmpty) {
      // 加载中显示加载器，加载完成后显示"不在家"
      if (_isLoading) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('正在连接直播间...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      }
      return const Center(
        child: Text(
          '主播不在家...',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    if (_currentRole == ClientRoleType.clientRoleBroadcaster) {
      return Stack(children: list);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (list.length == 1) return list[0];
        if (list.length == 2) {
          return Column(
            children: [
              Expanded(child: list[0]),
              Expanded(child: list[1]),
            ],
          );
        }
        return GridView.count(crossAxisCount: 2, children: list);
      },
    );
  }

  Widget _toolbarButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          ignoring: _isLoading,
          child: Opacity(
            opacity: _isLoading ? 0.5 : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoPopover(
                  backgroundColor: const Color(0xFF222222),
                  borderRadius: 16,
                  popoverBuilder: (context, controller) => GiftPickerContent(
                    controller: controller,
                    onSelected: _sendGift,
                    onDismiss: () => controller.dismiss(),
                  ),
                  verticalGap: 10,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RawMaterialButton(
                  onPressed: () => context.push('/chat/好友A'),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  shape: const CircleBorder(),
                  fillColor: Colors.white,
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        RawMaterialButton(
          onPressed: () => context.pop(),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          shape: const CircleBorder(),
          fillColor: Colors.redAccent,
          child: const Icon(Icons.close, color: Colors.white, size: 24.0),
        ),
      ],
    );
  }

  Widget _buildBroadcasterControls(bool isLandscape) {
    return IgnorePointer(
      ignoring: _isLoading,
      child: Opacity(
        opacity: _isLoading ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IntrinsicWidth(
            child: isLandscape
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildControlButton(
                        icon: Icons.switch_camera,
                        label: '翻转',
                        onTap: _onToggleCamera,
                      ),
                      _buildControlButton(
                        icon: _isLocalVideoEnabled
                            ? Icons.videocam
                            : Icons.videocam_off,
                        label: '视频',
                        onTap: _onToggleVideo,
                        color: _isLocalVideoEnabled ? Colors.white : Colors.red,
                      ),
                      _buildControlButton(
                        icon: Icons.high_quality,
                        label: _currentQuality,
                        onTap: _onSelectQuality,
                      ),
                      _buildControlButton(
                        icon:
                            _agoraService.activeSource ==
                                AgoraVideoSource.mediaPlayer
                            ? Icons.videocam
                            : Icons.movie_filter,
                        label:
                            _agoraService.activeSource ==
                                AgoraVideoSource.mediaPlayer
                            ? '切摄像头'
                            : '切视频',
                        onTap: _onSwitchSource,
                        color:
                            _agoraService.activeSource ==
                                AgoraVideoSource.mediaPlayer
                            ? Colors.orange
                            : Colors.white,
                      ),
                      _buildControlButton(
                        icon: _isScreenSharing
                            ? Icons.screen_share
                            : (_isMediaPlayerPlaying
                                  ? Icons.movie
                                  : Icons.more_horiz),
                        label: _isScreenSharing
                            ? '共享中'
                            : (_isMediaPlayerPlaying ? '播放中' : '更多'),
                        onTap: _showMoreOptions,
                        color: (_isScreenSharing || _isMediaPlayerPlaying)
                            ? Colors.blue
                            : Colors.white,
                      ),
                      _buildZoomSlider(isLandscape),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildControlButton(
                        icon: Icons.switch_camera,
                        label: '翻转',
                        onTap: _onToggleCamera,
                      ),
                      _buildControlButton(
                        icon: _isLocalVideoEnabled
                            ? Icons.videocam
                            : Icons.videocam_off,
                        label: '视频',
                        onTap: _onToggleVideo,
                        color: _isLocalVideoEnabled ? Colors.white : Colors.red,
                      ),
                      _buildControlButton(
                        icon: Icons.high_quality,
                        label: _currentQuality,
                        onTap: _onSelectQuality,
                      ),
                      _buildControlButton(
                        icon: _isScreenSharing
                            ? Icons.screen_share
                            : (_isMediaPlayerPlaying
                                  ? Icons.movie
                                  : Icons.more_horiz),
                        label: _isScreenSharing
                            ? '共享中'
                            : (_isMediaPlayerPlaying ? '播放中' : '更多'),
                        onTap: _showMoreOptions,
                        color: (_isScreenSharing || _isMediaPlayerPlaying)
                            ? Colors.blue
                            : Colors.white,
                      ),
                      const SizedBox(height: 8),
                      _buildZoomSlider(isLandscape),
                      const Text(
                        '缩放',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _showMoreOptions() {
    SmartDialog.show(
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '高级功能',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                _isScreenSharing ? Icons.stop : Icons.screen_share,
                color: Colors.white,
              ),
              title: Text(
                _isScreenSharing ? '停止屏幕共享' : '开始屏幕共享',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                SmartDialog.dismiss();
                _onToggleScreenShare();
              },
            ),
            ListTile(
              leading: Icon(
                _isMediaPlayerPlaying ? Icons.stop : Icons.movie,
                color: Colors.white,
              ),
              title: Text(
                _isMediaPlayerPlaying ? '停止视频推送' : '推送在线视频',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                SmartDialog.dismiss();
                _onToggleMediaPlayer();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomSlider(bool isLandscape) {
    if (isLandscape) {
      return SizedBox(
        width: 100,
        height: 40,
        child: Slider(
          value: _zoomFactor.clamp(1.0, 5.0),
          min: 1.0,
          max: 5.0,
          activeColor: Colors.blue,
          inactiveColor: Colors.white24,
          onChanged: _onZoomChanged,
        ),
      );
    }
    return RotatedBox(
      quarterTurns: 3,
      child: SizedBox(
        height: 40,
        width: 100,
        child: Slider(
          value: _zoomFactor.clamp(1.0, 5.0),
          min: 1.0,
          max: 5.0,
          activeColor: Colors.blue,
          inactiveColor: Colors.white24,
          onChanged: _onZoomChanged,
        ),
      ),
    );
  }

  void _navigateToLandscape() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => LandscapePlayerPage(
              agoraService: _agoraService,
              totalDuration: _mediaDuration,
              currentPosition: _mediaPosition,
              isLiveSync: _isLiveSync,
              onSeek: (pos) {
                _seekTo(pos);
                setState(() => _isLiveSync = false);
              },
              onGoLive: () {
                setState(() => _isLiveSync = true);
              },
            ),
          ),
        )
        .then((_) {
          // Force refresh when back
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          setState(() {});
        });
  }

  void _startBroadcasterSync() {
    _syncTimer?.cancel();
    if (widget.role == ClientRoleType.clientRoleBroadcaster) {
      _syncTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (!_isMediaPlayerPlaying) return;
        final pos = await _agoraService.mediaPlayer?.getPlayPosition() ?? 0;
        final duration = await _agoraService.mediaPlayer?.getDuration() ?? 0;

        final msg = {
          'type': 'sync',
          'url': _currentMediaUrl ?? '',
          'pos': pos,
          'status': 'playing',
          'duration': duration,
        };
        // Send via RTM
        await _agoraService.sendInChannelMessage(jsonEncode(msg));
      });
    }
  }

  void _seekTo(Duration position) {
    if (_agoraService.mediaPlayer != null) {
      _agoraService.mediaPlayer!.seek(position.inMilliseconds);
      _showOverlay();
    }
  }

  void _showOverlay() {
    setState(() => _isOverlayVisible = true);
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isOverlayVisible = false);
    });
  }

  void _toggleOverlay() {
    if (_isOverlayVisible) {
      setState(() => _isOverlayVisible = false);
    } else {
      _showOverlay();
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
