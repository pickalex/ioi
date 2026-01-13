import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/agora_service.dart';
import '../widgets/sports_player_overlay.dart';

class LandscapePlayerPage extends StatefulWidget {
  final AgoraService agoraService;
  final Duration totalDuration;
  final Duration currentPosition;
  final bool isLiveSync;
  final Function(Duration) onSeek;
  final VoidCallback onGoLive;

  const LandscapePlayerPage({
    super.key,
    required this.agoraService,
    required this.totalDuration,
    required this.currentPosition,
    required this.isLiveSync,
    required this.onSeek,
    required this.onGoLive,
  });

  @override
  State<LandscapePlayerPage> createState() => _LandscapePlayerPageState();
}

class _LandscapePlayerPageState extends State<LandscapePlayerPage> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video View
          Center(
            child: AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: widget.agoraService.engine,
                canvas: VideoCanvas(
                  uid: 0, // Local player
                  sourceType: VideoSourceType.videoSourceMediaPlayer,
                  mediaPlayerId:
                      widget.agoraService.mediaPlayer?.getMediaPlayerId() ?? 0,
                ),
              ),
            ),
          ),

          // Overlay
          if (_showControls)
            SportsPlayerOverlay(
              totalDuration: widget.totalDuration,
              currentPosition: widget.currentPosition,
              isLive: widget.isLiveSync,
              onSeek: widget.onSeek,
              onToggleFullscreen: () => Navigator.of(context).pop(),
              isLandscape: true,
              onGoLive: widget.onGoLive,
            ),

          // Toggle tap
          if (!_showControls)
            GestureDetector(
              onTap: () => setState(() => _showControls = true),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
        ],
      ),
    );
  }
}
