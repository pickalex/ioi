import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart' as rtm;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../utils/agora_token_builder.dart';

enum AgoraVideoSource { camera, mediaPlayer, screenShare }

enum VideoQuality {
  sd_360p, // 标清
  hd_480p, // 高清
  hd_720p, // 超清
  fhd_1080p, // 蓝光
  uhd_2k, // 2K
  uhd_4k, // 4K
}

extension VideoQualityExt on VideoQuality {
  VideoDimensions get dimensions {
    switch (this) {
      case VideoQuality.sd_360p:
        return const VideoDimensions(width: 640, height: 360);
      case VideoQuality.hd_480p:
        return const VideoDimensions(width: 854, height: 480);
      case VideoQuality.hd_720p:
        return const VideoDimensions(width: 1280, height: 720);
      case VideoQuality.fhd_1080p:
        return const VideoDimensions(width: 1920, height: 1080);
      case VideoQuality.uhd_2k:
        return const VideoDimensions(width: 2560, height: 1440);
      case VideoQuality.uhd_4k:
        return const VideoDimensions(width: 3840, height: 2160);
    }
  }

  String get label {
    switch (this) {
      case VideoQuality.sd_360p:
        return '标清';
      case VideoQuality.hd_480p:
        return '高清';
      case VideoQuality.hd_720p:
        return '超清';
      case VideoQuality.fhd_1080p:
        return '蓝光';
      case VideoQuality.uhd_2k:
        return '2K';
      case VideoQuality.uhd_4k:
        return '4K';
    }
  }
}

/// Agora 服务的核心入口，采用单例模式
/// 通过 Mixin 将复杂的逻辑拆分为 RTC, RTM, 媒体处理、视频效果和本地转码五个模块
class AgoraService
    with
        AgoraRtcMixin,
        AgoraRtmMixin,
        AgoraMediaMixin,
        AgoraEffectMixin,
        AgoraTranscoderMixin {
  static const String appId = "68d51391562342d1a669b890a019ef2c";
  static const String appCertificate = "e6e2a63ef34d461db0ab245be84a03a7";

  // 单例模式
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  // --- 核心引擎实例 ---
  RtcEngine? _engine;
  rtm.RtmClient? _rtmClient;
  MediaPlayer? _mediaPlayer;

  // --- 状态标识 ---
  String? _currentRtmUserId;
  bool _isRtcInitialized = false;
  bool _isRtmLoggedIn = false;
  bool _isScreenSharing = false;
  bool _isMediaPlayerPlaying = false;
  AgoraVideoSource _activeSource = AgoraVideoSource.camera;
  bool _enableMediaPlayerPublish = true;
  VideoQuality _currentQuality = VideoQuality.hd_720p;

  // --- Getters ---
  RtcEngine? get engineInstance => _engine;
  bool get isRtmLoggedIn => _isRtmLoggedIn;
  bool get isRtcInitialized => _isRtcInitialized;
  bool get isScreenSharing => _isScreenSharing;
  bool get isMediaPlayerPlaying => _isMediaPlayerPlaying;
  AgoraVideoSource get activeSource => _activeSource;
  String? get currentRtmUserId => _currentRtmUserId;
  MediaPlayer? get mediaPlayer => _mediaPlayer;
  VideoQuality get currentQuality => _currentQuality;

  // --- 事件流 (Streams) ---
  final StreamController<String> _logController = StreamController.broadcast();
  Stream<String> get logStream => _logController.stream;

  final StreamController<RtcConnection> _connectionController =
      StreamController.broadcast();
  Stream<RtcConnection> get connectionStream => _connectionController.stream;

  final StreamController<int> _userJoinedController =
      StreamController.broadcast();
  Stream<int> get userJoinedStream => _userJoinedController.stream;

  final StreamController<int> _userOfflineController =
      StreamController.broadcast();
  Stream<int> get userOfflineStream => _userOfflineController.stream;

  final StreamController<MediaPlayerState> _playerStateController =
      StreamController.broadcast();
  Stream<MediaPlayerState> get playerStateStream =>
      _playerStateController.stream;

  final StreamController<AgoraVideoSource> _activeSourceController =
      StreamController.broadcast();
  Stream<AgoraVideoSource> get activeSourceStream =>
      _activeSourceController.stream;

  final StreamController<rtm.MessageEvent> _messageController =
      StreamController.broadcast();
  Stream<rtm.MessageEvent> get messageStream => _messageController.stream;

  // --- 常用 Getter (带异常检查) ---
  rtm.RtmClient get rtmClient {
    if (_rtmClient == null) {
      throw Exception("AgoraService RTM not initialized.");
    }
    return _rtmClient!;
  }

  RtcEngine get engine {
    if (_engine == null) throw Exception("AgoraService RTC not initialized.");
    return _engine!;
  }

  // --- 生命周期管理 ---
  Future<void> release() async {
    if (_mediaPlayer != null) {
      await _engine?.destroyMediaPlayer(_mediaPlayer!);
      _mediaPlayer = null;
    }
    await _engine?.release();
    await _rtmClient?.release();
    _isRtcInitialized = false;
    _isRtmLoggedIn = false;
    _isScreenSharing = false;
    _isMediaPlayerPlaying = false;
    _engine = null;
    _rtmClient = null;
  }

  void dispose() {
    _logController.close();
    _connectionController.close();
    _userJoinedController.close();
    _userOfflineController.close();
    _playerStateController.close();
    _activeSourceController.close();
    _messageController.close();
  }
}

// =============================================================================
// RTC 模块: 负责频道加入、退出、摄像头控制等
// =============================================================================
mixin AgoraRtcMixin {
  AgoraService get _s => AgoraService();

  Future<void> initEngine() async {
    if (_s._engine != null) return;
    _s._engine = createAgoraRtcEngine();
    await _s._engine!.initialize(
      const RtcEngineContext(
        appId: AgoraService.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    debugPrint("✅ Agora Engine Initialized");
  }

  Future<void> initRtc() async {
    if (_s._isRtcInitialized) return;
    await initEngine();

    _s._engine!.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint("User joined: $remoteUid");
          _s._userJoinedController.add(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint("User offline: $remoteUid, reason: $reason");
          _s._userOfflineController.add(remoteUid);
        },
        onConnectionStateChanged: (connection, state, reason) {
          if (state == ConnectionStateType.connectionStateConnected) {
            _s._connectionController.add(connection);
            _s._logController.add("Joined Channel Success");
          }
        },
        onError: (err, msg) => _s._logController.add("Error: $err $msg"),
      ),
    );

    await _s._engine!.enableVideo();
    _s._isRtcInitialized = true;
    debugPrint("✅ Agora RTC Initialized");
  }

  Future<void> joinChannel({
    required String channelId,
    required ClientRoleType role,
    int uid = 0,
    bool isAudioOnly = false,
  }) async {
    if (!_s._isRtcInitialized) await initRtc();
    await _s._engine!.setClientRole(role: role);

    if (isAudioOnly) {
      await _s._engine!.disableVideo();
      await _s._engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
    } else {
      await _s._engine!.enableVideo();
      if (role == ClientRoleType.clientRoleBroadcaster) {
        await _s._engine!.startPreview();
      }
    }

    int effectiveUid = uid != 0
        ? uid
        : DateTime.now().millisecondsSinceEpoch % 1000000 + 1;
    final token = AgoraTokenBuilder.buildRtcToken(
      appId: AgoraService.appId,
      appCertificate: AgoraService.appCertificate,
      channelName: channelId,
      uid: effectiveUid.toString(),
      role: role == ClientRoleType.clientRoleBroadcaster ? 1 : 2,
    );

    await _s._engine!.joinChannel(
      token: token,
      channelId: channelId,
      uid: effectiveUid,
      options: ChannelMediaOptions(
        publishCameraTrack:
            !isAudioOnly && role == ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: role == ClientRoleType.clientRoleBroadcaster,
        clientRoleType: role,
        autoSubscribeAudio: true,
        autoSubscribeVideo: !isAudioOnly,
      ),
    );
  }

  Future<void> leaveChannel() async => await _s._engine?.leaveChannel();
  Future<void> switchRole(ClientRoleType role) async =>
      await _s._engine?.setClientRole(role: role);
  Future<void> switchCamera() async => await _s._engine?.switchCamera();
  Future<void> setCameraZoomFactor(double factor) async =>
      await _s._engine?.setCameraZoomFactor(factor);
  Future<void> setLocalVideoEnabled(bool enabled) async =>
      await _s._engine?.enableLocalVideo(enabled);

  Future<void> disposeLiveConnection() async {
    if (_s._mediaPlayer != null) await _s._mediaPlayer?.stop();
    _s._isMediaPlayerPlaying = false;
    _s._activeSource = AgoraVideoSource.camera;
    await _s._engine?.leaveChannel();
    _s._isRtcInitialized = false;
  }
}

// =============================================================================
// RTM 模块: 负责消息收发、点对点通信
// =============================================================================
mixin AgoraRtmMixin {
  AgoraService get _s => AgoraService();

  Future<void> initRtm(String userId) async {
    if (_s._isRtmLoggedIn) return;
    await _s.initEngine();

    final (status, client) = await rtm.RTM(AgoraService.appId, userId);
    if (status.error) return;

    _s._rtmClient = client;
    _s._currentRtmUserId = userId;
    final rtmToken = AgoraTokenBuilder.rtmToken(userId);

    final (loginStatus, _) = await _s._rtmClient!.login(rtmToken);
    if (!loginStatus.error) {
      _s._isRtmLoggedIn = true;
      _s._rtmClient!.addListener(
        message: (event) => _s._messageController.add(event),
      );
    }
  }

  Future<void> subscribeToInbox(String userId) async {
    if (_s._rtmClient == null) return;
    await _s._rtmClient!.subscribe(
      'inbox_$userId',
      withMessage: true,
      withMetadata: true,
      withPresence: true,
    );
  }

  Future<void> sendPeerMessage(String targetUserId, String content) async {
    if (_s._rtmClient == null) return;
    await _s._rtmClient!.publish(
      'inbox_$targetUserId',
      content,
      channelType: rtm.RtmChannelType.message,
      customType: 'text',
      storeInHistory: true,
    );
  }

  Future<void> sendInChannelMessage(String msg) async {
    if (_s._rtmClient == null || !_s._isRtmLoggedIn) return;
    await _s._rtmClient!.publish(
      _s._currentRtmUserId ?? '',
      msg,
      customType: 'sync',
    );
  }

  Future<List<rtm.HistoryMessage>> fetchInboxHistory(String userId) async => [];
}

// =============================================================================
// 媒体模块: 负责媒体播放器、屏幕共享、推流源切换
// =============================================================================
mixin AgoraMediaMixin {
  AgoraService get _s => AgoraService();

  final StreamController<bool> _videoLoadingController =
      StreamController<bool>.broadcast();
  Stream<bool> get videoLoadingStream => _videoLoadingController.stream;

  // 跟踪最后的播放器状态
  MediaPlayerState? _lastPlayerState;
  MediaPlayerState? get lastPlayerState => _lastPlayerState;

  Future<void> initMediaPlayer() async {
    if (_s._mediaPlayer != null || _s._engine == null) return;
    _s._mediaPlayer = await _s._engine!.createMediaPlayer();

    _s._mediaPlayer!.registerPlayerSourceObserver(
      MediaPlayerSourceObserver(
        onPlayerSourceStateChanged: (state, error) {
          _lastPlayerState = state;
          _s._playerStateController.add(state);
          if (state == MediaPlayerState.playerStateOpenCompleted) {
            _s._mediaPlayer!.play();
            if (_s._enableMediaPlayerPublish) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_s.isMediaPlayerPlaying) {
                  setActiveSource(AgoraVideoSource.mediaPlayer);
                }
              });
            }
          } else if (state == MediaPlayerState.playerStatePlaybackCompleted) {
            if (_s._enableMediaPlayerPublish) {
              setActiveSource(AgoraVideoSource.camera);
            }
          }
        },
      ),
    );
  }

  Future<void> startMediaPlayer(
    String url, {
    bool publish = true,
    int startPos = 0,
  }) async {
    if (_s._engine == null) return;
    if (_s._mediaPlayer == null) await initMediaPlayer();
    _s._enableMediaPlayerPublish = publish;
    await _s._mediaPlayer!.open(url: url, startPos: startPos);
    _s._isMediaPlayerPlaying = true;
  }

  Future<void> stopMediaPlayer() async {
    await _s._mediaPlayer?.stop();
    _s._isMediaPlayerPlaying = false;
    if (_s._activeSource == AgoraVideoSource.mediaPlayer) {
      _s._activeSource = AgoraVideoSource.camera;
    }
    await updatePublishSource();
  }

  Future<void> pauseMediaPlayer() async => await _s._mediaPlayer?.pause();
  Future<void> resumeMediaPlayer() async => await _s._mediaPlayer?.resume();
  Future<void> seekMediaPlayer(int position) async =>
      await _s._mediaPlayer?.seek(position);

  /// 安全播放 - 仅在播放器状态允许时调用 play()
  /// 防止 AgoraRtcException(-2) 错误
  Future<bool> safePlayMediaPlayer() async {
    final state = _lastPlayerState;
    // 只有在 openCompleted 或 paused 状态时才能安全调用 play()
    if (state == MediaPlayerState.playerStateOpenCompleted ||
        state == MediaPlayerState.playerStatePaused) {
      try {
        await _s._mediaPlayer?.play();
        return true;
      } catch (e) {
        debugPrint('safePlayMediaPlayer failed: $e');
        return false;
      }
    }
    debugPrint('safePlayMediaPlayer skipped - state: $state');
    return false;
  }

  /// 安全恢复 - 检查状态后调用 resume()
  Future<bool> safeResumeMediaPlayer() async {
    final state = _lastPlayerState;
    if (state == MediaPlayerState.playerStatePaused ||
        state == MediaPlayerState.playerStatePlaying) {
      try {
        await _s._mediaPlayer?.resume();
        return true;
      } catch (e) {
        debugPrint('safeResumeMediaPlayer failed: $e');
        return false;
      }
    }
    debugPrint('safeResumeMediaPlayer skipped - state: $state');
    return false;
  }

  Future<void> adjustMediaPlayerPublishVolume(int volume) async =>
      await _s._mediaPlayer?.adjustPublishSignalVolume(volume);

  Future<void> setActiveSource(AgoraVideoSource source) async {
    _s._activeSource = source;
    if (source == AgoraVideoSource.mediaPlayer && !_s._isMediaPlayerPlaying) {
      _s._activeSource = AgoraVideoSource.camera;
    }
    if (source == AgoraVideoSource.screenShare && !_s._isScreenSharing) {
      _s._activeSource = AgoraVideoSource.camera;
    }
    _s._activeSourceController.add(_s._activeSource);
    await updatePublishSource();
  }

  Future<void> startScreenShare() async {
    if (_s._engine == null) return;
    await _s._engine!.startScreenCapture(
      const ScreenCaptureParameters2(captureAudio: true, captureVideo: true),
    );
    _s._isScreenSharing = true;
    await updatePublishSource();
  }

  Future<void> stopScreenShare() async {
    await _s._engine?.stopScreenCapture();
    _s._isScreenSharing = false;
    if (_s._activeSource == AgoraVideoSource.screenShare) {
      _s._activeSource = AgoraVideoSource.camera;
    }
    await updatePublishSource();
  }

  Future<void> updatePublishSource() async {
    if (_s._engine == null) return;
    bool isShare = _s._activeSource == AgoraVideoSource.screenShare;
    bool isMP = _s._activeSource == AgoraVideoSource.mediaPlayer;
    bool isCam = _s._activeSource == AgoraVideoSource.camera;

    await _s._engine!.updateChannelMediaOptions(
      ChannelMediaOptions(
        publishCameraTrack: isCam,
        publishMicrophoneTrack: true,
        publishScreenTrack: isShare,
        publishMediaPlayerVideoTrack: isMP,
        publishMediaPlayerAudioTrack: isMP,
        publishMediaPlayerId: isMP ? _s._mediaPlayer?.getMediaPlayerId() : null,
      ),
    );

    await _s._engine!.setVideoEncoderConfiguration(
      VideoEncoderConfiguration(
        dimensions: _s._currentQuality.dimensions,
        frameRate: isMP ? 24 : 15,
        degradationPreference: isMP
            ? DegradationPreference.maintainQuality
            : DegradationPreference.maintainBalanced,
      ),
    );
  }

  Future<AgoraMediaPlayerHandle?> createIndependentPlayer() async {
    if (_s._engine == null) return null;
    final player = await _s._engine!.createMediaPlayer();
    if (player == null) return null;
    final controller = StreamController<MediaPlayerState>.broadcast();
    player.registerPlayerSourceObserver(
      MediaPlayerSourceObserver(
        onPlayerSourceStateChanged: (state, error) => controller.add(state),
      ),
    );
    return AgoraMediaPlayerHandle(
      player: player,
      controller: controller,
      onDispose: () async => await _s._engine?.destroyMediaPlayer(player),
    );
  }
}

// =============================================================================
// 特效与工具模块: 负责美颜、水印、视频质量
// =============================================================================
mixin AgoraEffectMixin {
  AgoraService get _s => AgoraService();

  Future<void> setBeautyEffect(bool enabled) async {
    await _s._engine?.setBeautyEffectOptions(
      enabled: enabled,
      options: const BeautyOptions(
        lighteningContrastLevel:
            LighteningContrastLevel.lighteningContrastNormal,
        lighteningLevel: 0.7,
        smoothnessLevel: 0.5,
        rednessLevel: 0.1,
        sharpnessLevel: 0.1,
      ),
    );
  }

  Future<void> setVideoQuality(
    VideoQuality quality, {
    int frameRate = 15,
  }) async {
    _s._currentQuality = quality;
    await _s._engine?.setVideoEncoderConfiguration(
      VideoEncoderConfiguration(
        dimensions: quality.dimensions,
        frameRate: frameRate,
      ),
    );
    debugPrint("✅ Video quality set to: ${quality.name}");
  }

  Future<void> setWatermark({
    String? url,
    bool visibleInPreview = true,
    int x = 10,
    int y = 10,
    int width = 60,
    int height = 60,
  }) async {
    if (_s._engine == null) return;
    if (url == null) return await _s._engine!.clearVideoWatermarks();

    final options = WatermarkOptions(
      visibleInPreview: visibleInPreview,
      positionInLandscapeMode: Rectangle(
        x: x,
        y: y,
        width: width,
        height: height,
      ),
      positionInPortraitMode: Rectangle(
        x: x,
        y: y,
        width: width,
        height: height,
      ),
    );
    await _s._engine!.addVideoWatermark(watermarkUrl: url, options: options);
  }
}

// =============================================================================
// 本地转码模块: 负责将多个视频源（摄像头、屏幕、播放器、图片）合成为一个画面推流
// =============================================================================
mixin AgoraTranscoderMixin {
  AgoraService get _s => AgoraService();

  /// 启动本地视频转码器
  Future<void> startLocalVideoTranscoder(
    LocalTranscoderConfiguration config,
  ) async {
    if (_s._engine == null) return;
    try {
      await _s._engine!.startLocalVideoTranscoder(config);
      // 启动转码特有的预览
      await _s._engine!.startPreview(
        sourceType: VideoSourceType.videoSourceTranscoded,
      );
      debugPrint("✅ Local Video Transcoder Started");
    } catch (e) {
      debugPrint("❌ Start Local Video Transcoder Error: $e");
    }
  }

  /// 更新本地视频转码器配置
  Future<void> updateLocalTranscoderConfiguration(
    LocalTranscoderConfiguration config,
  ) async {
    if (_s._engine == null) return;
    try {
      await _s._engine!.updateLocalTranscoderConfiguration(config);
      debugPrint("✅ Local Video Transcoder Configuration Updated");
    } catch (e) {
      debugPrint("❌ Update Local Video Transcoder Error: $e");
    }
  }

  /// 停止本地视频转码器
  Future<void> stopLocalVideoTranscoder() async {
    if (_s._engine == null) return;
    try {
      await _s._engine!.stopLocalVideoTranscoder();
      // 停止后恢复默认预览
      await _s._engine!.startPreview();
      debugPrint("✅ Local Video Transcoder Stopped");
    } catch (e) {
      debugPrint("❌ Stop Local Video Transcoder Error: $e");
    }
  }

  /// 工具方法：将 Assets 图片复制到临时目录并返回完整路径（转码器需要绝对路径）
  Future<String> getTranscoderFilePath(String fileName) async {
    ByteData data = await rootBundle.load("assets/$fileName");
    List<int> bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String p = path.join(appDocDir.path, fileName);
    final file = File(p);
    if (!(await file.exists())) {
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
    return p;
  }
}

// =============================================================================
// 工具类
// =============================================================================
class AgoraMediaPlayerHandle {
  final MediaPlayer player;
  final StreamController<MediaPlayerState> _controller;
  final Future<void> Function() onDispose;
  Stream<MediaPlayerState> get stateStream => _controller.stream;

  AgoraMediaPlayerHandle({
    required this.player,
    required StreamController<MediaPlayerState> controller,
    required this.onDispose,
  }) : _controller = controller;

  Future<void> dispose() async {
    await onDispose();
    await _controller.close();
  }
}
