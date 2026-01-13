import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/agora_service.dart';
import '../widgets/sports_player_overlay.dart';

/// 横屏播放页面 - LivePage3 专用
class LandscapeLivePage3 extends StatefulWidget {
  final String channelName;
  final bool initialIsLive;
  final Duration initialPos;
  final Duration totalDuration;
  final String vodUrl;
  final AgoraMediaPlayerHandle playerHandle;

  const LandscapeLivePage3({
    super.key,
    required this.channelName,
    required this.initialIsLive,
    required this.totalDuration,
    required this.initialPos,
    required this.vodUrl,
    required this.playerHandle,
  });

  @override
  State<LandscapeLivePage3> createState() => _LandscapeLivePage3State();
}

class _LandscapeLivePage3State extends State<LandscapeLivePage3> {
  final _agoraService = AgoraService();

  late bool _isLive;
  late Duration _currentPos;
  late Duration _totalDuration;

  VideoViewController? _rtcController;
  VideoViewController? _mediaController;
  Timer? _progressTimer;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _isLive = widget.initialIsLive;
    _currentPos = widget.initialPos;
    _totalDuration = widget.totalDuration;

    // 强制横屏
    Future.delayed(Duration(milliseconds: 200), () {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });

    _init();
  }

  void _init() {
    // 启动进度更新定时器
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isLive && mounted) {
        _updateVodProgress();
      } else if (_isLive && mounted) {
        setState(() => _currentPos = _totalDuration);
      }
    });

    if (_isLive) {
      _setupRtc();
    } else {
      _setupVod();
      // 进入横屏自动播放 VOD
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (mounted && !_isLive) {
          try {
            await widget.playerHandle.player.resume();
          } catch (e) {
            debugPrint('Auto-resume failed. Re-opening: $e');
            // 如果 resume 失败，重新 open
            try {
              await widget.playerHandle.player.open(
                url: widget.vodUrl,
                startPos: widget.initialPos.inMilliseconds,
              );
            } catch (e2) {
              debugPrint('Re-open failed: $e2');
            }
          }
        }
      });
    }

    _agoraService.userJoinedStream.listen((uid) {
      if (mounted && _isLive) {
        _setupRtc(uid: uid);
      }
    });

    // 监听播放结束 (Use dedicated stream from handle)
    _playerStateSubscription = widget.playerHandle.stateStream.listen((state) {
      if (state == MediaPlayerState.playerStatePlaybackAllLoopsCompleted &&
          mounted &&
          !_isLive) {
        _goLive();
      }
    });
  }

  StreamSubscription? _playerStateSubscription;

  void _setupRtc({int? uid}) {
    setState(() {
      _rtcController = VideoViewController(
        rtcEngine: _agoraService.engine,
        canvas: VideoCanvas(uid: uid ?? 0),
      );
    });
  }

  void _setupVod() {
    final mpId = widget.playerHandle.player.getMediaPlayerId();
    setState(() {
      _mediaController = VideoViewController(
        rtcEngine: _agoraService.engine,
        canvas: VideoCanvas(
          uid: mpId,
          sourceType: VideoSourceType.videoSourceMediaPlayer,
        ),
        useFlutterTexture: true,
      );
    });
  }

  Future<void> _updateVodProgress() async {
    if (!mounted) return;
    try {
      final pos = await widget.playerHandle.player.getPlayPosition();
      if (pos >= 0 && mounted) {
        setState(() => _currentPos = Duration(milliseconds: pos));
      }
    } catch (e) {
      // 忽略
    }
  }

  @override
  void dispose() {
    // 恢复竖屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _progressTimer?.cancel();
    _playerStateSubscription?.cancel();

    // 必须释放控制器，因为它们是本页面创建的
    _rtcController?.dispose();
    _mediaController?.dispose();

    super.dispose();
  }

  // --- 用户操作 ---

  void _onSeek(Duration target) async {
    if (!mounted) return;

    // 拖到接近结尾时切换到直播
    if ((_totalDuration - target).inSeconds < 2) {
      _goLive();
      return;
    }

    if (_isLive) {
      await _switchToVod();
    }

    try {
      await widget.playerHandle.player.seek(target.inMilliseconds);
      if (mounted) {
        setState(() => _currentPos = target);
      }
    } catch (e) {
      debugPrint('Seek failed: $e');
    }
  }

  Future<void> _switchToVod() async {
    if (!mounted) return;
    setState(() => _isLive = false);

    _setupVod();

    // 尝试 Resume，失败则 Open
    try {
      await widget.playerHandle.player.resume();
    } catch (e) {
      debugPrint('Resume in switch failed: $e');
      try {
        await widget.playerHandle.player.open(
          url: widget.vodUrl,
          startPos: _currentPos.inMilliseconds,
        );
      } catch (e2) {}
    }
  }

  void _goLive() async {
    if (!mounted || _isLive) return;
    setState(() => _isLive = true);

    try {
      await widget.playerHandle.player.pause();
    } catch (e) {}

    if (mounted) {
      setState(() {
        _currentPos = _totalDuration;
        _mediaController?.dispose();
        _mediaController = null;
      });
      _setupRtc();
    }
  }

  void _onPop() async {
    // 退出前主动暂停，确保状态明确 (避免报错 -2)
    if (!_isLive) {
      try {
        await widget.playerHandle.player.pause();
      } catch (_) {}
    }
    // 返回时传递当前状态给 LivePage2
    Navigator.of(context).pop({'isLive': _isLive, 'pos': _currentPos});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Center(
              child: _isLive
                  ? (_rtcController != null
                        ? AgoraVideoView(controller: _rtcController!)
                        : const Text(
                            "Waiting for Live...",
                            style: TextStyle(color: Colors.white),
                          ))
                  : (_mediaController != null
                        ? AgoraVideoView(controller: _mediaController!)
                        : const CircularProgressIndicator()),
            ),
            if (_showControls)
              Positioned.fill(
                child: SportsPlayerOverlay(
                  totalDuration: _totalDuration,
                  currentPosition: _currentPos,
                  isLive: _isLive,
                  onSeek: _onSeek,
                  onGoLive: _goLive,
                  onToggleFullscreen: _onPop,
                  isLandscape: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
