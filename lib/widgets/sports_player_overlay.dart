import 'package:flutter/material.dart';

class SportsPlayerOverlay extends StatelessWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final bool isLive; // True if sync with live edge
  final Function(Duration) onSeek;
  final VoidCallback onToggleFullscreen;
  final bool isLandscape;
  final VoidCallback? onGoLive;

  const SportsPlayerOverlay({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.isLive,
    required this.onSeek,
    required this.onToggleFullscreen,
    required this.isLandscape,
    this.onGoLive,
  });

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black87,
          ],
          stops: [0.0, 0.2, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top Bar
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                const BackButton(color: Colors.white),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isLandscape ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  onPressed: onToggleFullscreen,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Bottom Bar (Only show if we have a valid duration > 1s, implying VOD/Media)
          if (totalDuration.inSeconds > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info Row
                  Row(
                    children: [
                      // LIVE Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLive ? Colors.red : Colors.grey[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Back to Live button
                      if (!isLive)
                        GestureDetector(
                          onTap: () {
                            if (onGoLive != null) {
                              onGoLive!();
                            } else {
                              onSeek(totalDuration);
                            }
                          },
                          child: const Text(
                            '回到直播',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Seek Bar
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      trackHeight: 2,
                      activeTrackColor: Colors.redAccent,
                      inactiveTrackColor: Colors.white24,
                    ),
                    child: Slider(
                      value: currentPosition.inMilliseconds.toDouble().clamp(
                        0.0,
                        totalDuration.inMilliseconds.toDouble(),
                      ),
                      min: 0.0,
                      max: totalDuration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        final max = totalDuration.inMilliseconds.toDouble();
                        // If dragged close to the end (within 1 second), snap to live
                        if (value >= max - 1000) {
                          if (!isLive && onGoLive != null) {
                            onGoLive!();
                          }
                        } else {
                          onSeek(Duration(milliseconds: value.toInt()));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
