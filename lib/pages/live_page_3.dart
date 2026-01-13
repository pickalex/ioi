import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../services/agora_service.dart';
import '../widgets/sports_player_overlay.dart';
import 'landscape_live_page_3.dart';
import 'package:go_router/go_router.dart';

class LivePage3 extends StatefulWidget {
  final String channelName;

  const LivePage3({super.key, required this.channelName});

  @override
  State<LivePage3> createState() => _LivePage3State();
}

class _LivePage3State extends State<LivePage3> {
  final _agoraService = AgoraService();

  // State
  bool _isLive = true; // True = RTC, False = VOD
  Duration _currentPos = Duration.zero;
  Duration _totalDuration = Duration.zero; // Will be set from video

  // Test VOD URL
  final String _vodUrl = 'https://v-cdn.zjol.com.cn/280443.mp4';

  VideoViewController? _rtcController;
  VideoViewController? _mediaController; // Needed for rendering locally
  AgoraMediaPlayerHandle? _playerHandle; // Independent player handle
  Timer? _progressTimer;
  Timer? _seekDebounce; // Debounce for seek
  Timer? _durationRefreshTimer; // Refresh duration for DVR
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. Init RTC and join as Broadcaster (for camera preview)
    await _agoraService.initRtc();
    await _agoraService.joinChannel(
      channelId: widget.channelName,
      role: ClientRoleType.clientRoleBroadcaster,
    );

    // 2. Setup RTC Controller for local preview
    if (mounted) {
      _setupRemoteVideo(0);
    }

    // 3. Create Independent Media Player
    // Do NOT use _agoraService.initMediaPlayer() or _agoraService.mediaPlayer
    // allowing complete isolation from LivePage2
    _playerHandle = await _agoraService.createIndependentPlayer();
    if (_playerHandle == null) {
      debugPrint("Failed to create independent player");
      return;
    }

    // Preload video to get duration (won't display, just for metadata)
    // Open the video but immediately pause after open
    _playerStateSubscription = _playerHandle!.stateStream.listen((state) {
      if (state == MediaPlayerState.playerStateOpenCompleted) {
        _onPlayerOpened();
      } else if (state ==
          MediaPlayerState.playerStatePlaybackAllLoopsCompleted) {
        // 播放结束，自动转直播
        _goLive();
      }
    });

    // Open the video to get duration - it will auto-play, we'll pause it
    await _playerHandle!.player.open(url: _vodUrl, startPos: 0);

    // 4. Start Progress Timer
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isLive && mounted) {
        _updateVodProgress();
      }
    });

    // 5. Duration Refresh Timer (for growing DVR recordings)
    _durationRefreshTimer = Timer.periodic(const Duration(seconds: 10), (
      _,
    ) async {
      if (mounted && _playerHandle != null) {
        try {
          final dur = await _playerHandle!.player.getDuration();
          if (dur > 0 && mounted) {
            final newDuration = Duration(milliseconds: dur);
            if (newDuration > _totalDuration) {
              setState(() {
                _totalDuration = newDuration;
                if (_isLive) {
                  _currentPos = _totalDuration; // Keep at live edge
                }
              });
            }
          }
        } catch (_) {}
      }
    });

    // 6. Listen for remote user to update RTC canvas (for audience mode)
    _agoraService.userJoinedStream.listen((uid) {
      if (mounted) {
        _remoteUid = uid;
        _setupRemoteVideo(uid);
      }
    });
  }

  int _remoteUid = 0; // Default to local/broadcaster

  void _setupRemoteVideo(int uid) {
    if (!mounted) return;
    setState(() {
      _rtcController = VideoViewController(
        rtcEngine: _agoraService.engine,
        canvas: VideoCanvas(uid: uid),
      );
    });
  }

  Future<void> _onPlayerOpened() async {
    if (!mounted || _playerHandle == null) return;

    // Get duration
    final dur = await _playerHandle!.player.getDuration();
    if (dur > 0) {
      setState(() {
        _totalDuration = Duration(milliseconds: dur);
        _currentPos = _totalDuration; // Start at "live edge"
      });
    }

    // Setup media controller
    _rebuildMediaController();

    // Pause only if we are in LIVE mode (preloading).
    if (_isLive) {
      try {
        await _playerHandle!.player.pause();
      } catch (e) {
        debugPrint('Preload pause failed (ignored): $e');
      }
    } else {
      // If NOT live (VOD mode), we need to explicitly play because
      // independent player doesn't auto-play on open
      try {
        await _playerHandle!.player.play();
      } catch (e) {
        debugPrint('Auto-play failed: $e');
      }
    }
  }

  void _rebuildMediaController() {
    final mpId = _playerHandle?.player.getMediaPlayerId();
    if (mpId != null && mounted) {
      setState(() {
        _mediaController = VideoViewController(
          rtcEngine: _agoraService.engine,
          canvas: VideoCanvas(
            uid: mpId,
            sourceType: VideoSourceType.videoSourceMediaPlayer,
          ),
          useFlutterTexture: true, // Key for stability
        );
      });
    }
  }

  Future<void> _updateVodProgress() async {
    if (_playerHandle == null || !mounted) return;
    try {
      final pos = await _playerHandle!.player.getPlayPosition();
      if (pos >= 0 && mounted) {
        setState(() {
          _currentPos = Duration(milliseconds: pos);
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _seekDebounce?.cancel();
    _durationRefreshTimer?.cancel();
    _playerStateSubscription?.cancel();
    _rtcController?.dispose();
    _mediaController?.dispose();
    _agoraService.disposeLiveConnection();
    _playerHandle?.dispose(); // Dispose the independent player
    super.dispose();
  }

  // --- Actions ---

  void _onSeek(Duration target) {
    if (!mounted) return;

    // 1. Live Boundary Check
    if (_totalDuration.inSeconds > 0 &&
        (_totalDuration - target).inSeconds < 2) {
      _goLive();
      return;
    }

    // 2. Debounce seek
    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _performSeek(target);
    });
  }

  Future<void> _performSeek(Duration target) async {
    if (!mounted) return;

    // Switch to VOD if currently Live
    if (_isLive) {
      // 从直播切回 VOD并直接定位
      await _switchToVod(startPos: target);
      setState(() => _currentPos = target);
    } else {
      // 已经在 VOD，直接 Seek
      if (_playerHandle != null && mounted) {
        try {
          await _playerHandle!.player.seek(target.inMilliseconds);
          setState(() => _currentPos = target);
        } catch (e) {
          debugPrint("Seek exception: $e");
        }
      }
    }
  }

  Future<void> _switchToVod({Duration? startPos}) async {
    if (!mounted) return;
    setState(() => _isLive = false);

    // 1. 确保 Controller 存在 (因为 _goLive 销毁了它)
    if (_mediaController == null) {
      _rebuildMediaController();
    }

    // 2. 恢复播放并定位
    try {
      if (startPos != null) {
        // 如果指定了位置（Seek 触发），直接 Open 最稳妥
        await _playerHandle?.player.stop();
        await _playerHandle?.player.open(
          url: _vodUrl,
          startPos: startPos.inMilliseconds,
        );
      } else {
        // 无参调用 (普通切换)，尝试 Resume
        await _playerHandle?.player.resume();
      }
    } catch (e) {
      debugPrint('Switch VOD failed, re-opening video: $e');
      // 失败则重新 Open
      await _playerHandle?.player.open(
        url: _vodUrl,
        startPos: startPos?.inMilliseconds ?? 0,
      );
    }
  }

  void _goLive() async {
    if (!mounted || _isLive) return;

    setState(() => _isLive = true);
    // Pause instead of stop
    try {
      await _playerHandle?.player.pause();
    } catch (e) {
      debugPrint('Pause failed in _goLive: $e');
    }
    if (mounted) {
      setState(() {
        _currentPos = _totalDuration;
        // 销毁 VOD Controller
        _mediaController?.dispose();
        _mediaController = null;
      });
      // 恢复 RTC Controller
      _setupRemoteVideo(_remoteUid);
    }
  }

  void _navigateToLandscape() async {
    // 1. Navigation 前：先 Dispose 当前页面的 Controller
    // 释放 Texture 占用，避免多 View 抢占 Texture
    _mediaController?.dispose();
    _mediaController = null;
    _rtcController?.dispose();
    _rtcController = null;

    // 确保 VOD 暂停
    if (!_isLive) {
      try {
        await _playerHandle?.player.pause();
      } catch (_) {}
    }

    // Push to Landscape Page
    if (_playerHandle == null || !mounted) return;

    final result = await context.pushNamed('/live3/landscape', extra: {
      'channelName': widget.channelName,
      'isLive': _isLive,
      'totalDuration': _totalDuration,
      'initialPos': _currentPos,
      'vodUrl': _vodUrl,
      'playerHandle': _playerHandle!,
    });
    // final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => LandscapeLivePage3(channelName: widget.channelName, initialIsLive: _isLive, totalDuration: _totalDuration, initialPos: _currentPos, vodUrl: _vodUrl, playerHandle: _playerHandle!)));
    // Sync back state when returning
    if (result != null && result is Map && mounted) {
      final returnedIsLive = result['isLive'] == true;
      final returnedPos = result['pos'] as Duration;

      setState(() {
        _isLive = returnedIsLive;
        _currentPos = returnedPos;
      });

      // 2. Return 后：重建本页面的 Controller
      if (returnedIsLive) {
        // Live Mode
        _setupRemoteVideo(0);
        try {
          await _playerHandle?.player.pause();
        } catch (_) {}
      } else {
        // VOD Mode
        _rebuildMediaController();
        // Resume playback
        // 直接重新 Open，避免状态错误 (Error -2)
        // 从横屏返回时，播放器状态可能不确定，直接 Open 最稳妥
        Future.delayed(const Duration(milliseconds: 300), () async {
          if (!mounted) return;
          try {
            // 先 Stop 确保 clean state
            await _playerHandle?.player.stop();
            await _playerHandle?.player.open(
              url: _vodUrl,
              startPos: returnedPos.inMilliseconds,
            );
          } catch (e) {
            debugPrint('Open on return failed: $e');
          }
        });
      }
    } else {
      // 意外返回 (如手势) -> 恢复
      _onInitRestoration();
    }
  }

  void _onInitRestoration() {
    if (_isLive) {
      _setupRemoteVideo(0);
    } else {
      _rebuildMediaController();
      // _agoraService.mediaPlayer?.resume().catchError((_) {
      //   debugPrint("Restoration resume failed (ignored)");
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Layer
          Center(
            child: _isLive
                ? (_rtcController != null
                      ? AgoraVideoView(controller: _rtcController!)
                      : const Text(
                          "Starting Camera...",
                          style: TextStyle(color: Colors.white),
                        ))
                : (_mediaController != null
                      ? AgoraVideoView(controller: _mediaController!)
                      : const CircularProgressIndicator()),
          ),

          // Debug Info
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: Text(
                'Mode: ${_isLive ? "LIVE" : "VOD"}\n'
                'Pos: ${_currentPos.inSeconds}s / ${_totalDuration.inSeconds}s',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

          // Overlay (only show when duration is known)
          if (_totalDuration.inSeconds > 0 || _isLive)
            Positioned.fill(
              child: SportsPlayerOverlay(
                totalDuration: _totalDuration.inSeconds > 0
                    ? _totalDuration
                    : const Duration(seconds: 1),
                currentPosition: _isLive ? _totalDuration : _currentPos,
                isLive: _isLive,
                onSeek: _onSeek,
                onGoLive: _goLive,
                onToggleFullscreen: _navigateToLandscape,
                isLandscape: false,
              ),
            ),

          // Back Button
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
