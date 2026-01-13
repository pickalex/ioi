import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/agora_service.dart';

class VoiceRoomPage extends StatefulWidget {
  final String channelId;
  final String role; // 'host' or 'audience'

  const VoiceRoomPage({super.key, required this.channelId, required this.role});

  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage> {
  final AgoraService _agoraService = AgoraService();

  // 8 seats: null means empty, String means userId (mocked)
  final List<String?> _seats = List.filled(8, null);

  // Volume indication map: userId -> volume (0-255)
  final Map<String, int> _volumes = {};

  // Local User Status
  bool _isMicOn = true;
  int _mySeatIndex = -1; // -1 means not in seat

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 默认以 Audience 身份进入，只有上麦后才切换为 Broadcaster
    await _agoraService.joinChannel(
      channelId: widget.channelId,
      role: ClientRoleType.clientRoleAudience,
      uid: 0, // 0 means auto assign (but we mock user ID logic for seats locally)
      isAudioOnly: true,
    );

    _agoraService.engine.registerEventHandler(
      RtcEngineEventHandler(
        onAudioVolumeIndication:
            (
              RtcConnection connection,
              List<AudioVolumeInfo> speakers,
              int totalVolume,
              int? vad,
            ) {
              if (mounted) {
                setState(() {
                  _volumes.clear();
                  for (var speaker in speakers) {
                    // uid 0 is local user
                    String uid = (speaker.uid == 0)
                        ? '0'
                        : speaker.uid.toString();
                    _volumes[uid] = speaker.volume ?? 0;
                  }
                });
              }
            },
        onUserJoined: (connection, remoteUid, elapsed) {
          // 这里如果是真实应用，应该有人加入时，根据业务后台数据看他在哪个麦位
          debugPrint("User joined: $remoteUid");
        },
      ),
    );
  }

  @override
  void dispose() {
    _agoraService.leaveChannel();
    super.dispose();
  }

  void _toggleSeat(int index) async {
    if (_seats[index] != null && _seats[index] != '0') {
      // 别人占了
      SmartDialog.showToast('该麦位已被占用');
      return;
    }

    if (_mySeatIndex == index) {
      // 自己占了 -> 下麦
      await _agoraService.switchRole(ClientRoleType.clientRoleAudience);
      setState(() {
        _seats[index] = null;
        _mySeatIndex = -1;
      });
      SmartDialog.showToast('已下麦');
    } else if (_mySeatIndex != -1) {
      // 已经在其他麦位 -> 换麦 (简化逻辑：先下再上，或者直接换)
      setState(() {
        _seats[_mySeatIndex] = null; // 清空旧位
        _seats[index] = '0'; // 占新位 (0 代表自己)
        _mySeatIndex = index;
      });
      SmartDialog.showToast('已换到 ${index + 1} 号麦');
    } else {
      // 没在麦上 -> 上麦
      // 请求麦克风权限
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        await _agoraService.switchRole(ClientRoleType.clientRoleBroadcaster);
        setState(() {
          _seats[index] = '0';
          _mySeatIndex = index;
        });
        SmartDialog.showToast('上麦成功');
      } else {
        SmartDialog.showToast('无论是唱歌还是聊天，都需要麦克风权限哦~');
      }
    }
  }

  void _onToggleMic() {
    setState(() {
      _isMicOn = !_isMicOn;
    });
    _agoraService.engine.muteLocalAudioStream(!_isMicOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.channelId),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2B32B2),
              Color(0xFF1488CC),
            ], // Very cool blue gradient
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + 56,
            ), // Add padding for AppBar
            const Spacer(flex: 1),
            // Seats Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  return _buildSeatItem(index);
                },
              ),
            ),
            const Spacer(flex: 3),
            // Bottom Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatItem(int index) {
    final userId = _seats[index];
    final isTaken = userId != null;
    final isMe = userId == '0';

    // Check volume
    final volume = userId != null ? (_volumes[userId] ?? 0) : 0;
    final isTalking = volume > 5; // Threshold

    return GestureDetector(
      onTap: () => _toggleSeat(index),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple Effect
                if (isTalking)
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(
                          0.5 + min(volume, 100) / 200,
                        ),
                        width: 3,
                      ),
                    ),
                  ),
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: isMe
                        ? Border.all(color: Colors.amber, width: 2)
                        : null,
                  ),
                  child: isTaken
                      ? ClipOval(
                          child: Image.network(
                            'https://picsum.photos/seed/${index + 100}/100/100',
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.add, color: Colors.white54),
                ),
                // Mic Status Muted Icon (Mock logic: if I muted myself)
                if (isMe && !_isMicOn)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTaken ? (isMe ? '我' : '用户$index') : '${index + 1}号麦',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
        left: 24,
        right: 24,
      ),
      color: Colors.black12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.message_outlined, color: Colors.white),
          ),
          if (_mySeatIndex != -1) // Only show mic toggle if on seat
            GestureDetector(
              onTap: _onToggleMic,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isMicOn ? Colors.white : Colors.white24,
                ),
                child: Icon(
                  _isMicOn ? Icons.mic : Icons.mic_off,
                  color: _isMicOn ? Colors.blue : Colors.white,
                ),
              ),
            ),
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
