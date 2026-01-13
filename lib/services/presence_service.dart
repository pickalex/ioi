import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'agora_service.dart';
import 'friend_service.dart';

/// 用户在线状态
class UserPresence {
  final String userId;
  final bool isOnline;
  final bool isLive;
  final String? liveRoomId;
  final DateTime updatedAt;

  const UserPresence({
    required this.userId,
    this.isOnline = false,
    this.isLive = false,
    this.liveRoomId,
    required this.updatedAt,
  });

  UserPresence copyWith({bool? isOnline, bool? isLive, String? liveRoomId}) {
    return UserPresence(
      userId: userId,
      isOnline: isOnline ?? this.isOnline,
      isLive: isLive ?? this.isLive,
      liveRoomId: liveRoomId ?? this.liveRoomId,
      updatedAt: DateTime.now(),
    );
  }
}

/// Presence 服务 - 管理用户在线/直播状态
///
/// 使用 RTM 频道订阅广播状态消息
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final AgoraService _agoraService = AgoraService();

  // 状态同步频道名
  static const String _presenceChannel = 'presence_status';

  bool _isSubscribed = false;
  bool _listenerAdded = false;

  // 用户状态缓存
  final Map<String, UserPresence> _presenceCache = {};

  // 状态变化事件流
  final StreamController<UserPresence> _presenceController =
      StreamController<UserPresence>.broadcast();
  Stream<UserPresence> get presenceStream => _presenceController.stream;

  // 当前用户直播状态
  bool _isLive = false;
  String? _currentRoomId;

  /// 初始化 Presence 服务
  Future<void> init() async {
    if (!_agoraService.isRtmLoggedIn) {
      debugPrint('⚠️ RTM not logged in, cannot init Presence');
      return;
    }

    if (_isSubscribed) {
      debugPrint('✅ Presence already subscribed');
      return;
    }

    try {
      // 设置消息监听（只设置一次）
      if (!_listenerAdded) {
        _agoraService.rtmClient.addListener(
          message: (event) {
            // 检查是否是 presence 频道的消息
            if (event.channelName == _presenceChannel) {
              final sender = event.publisher ?? '';
              if (event.message != null) {
                try {
                  final content = utf8.decode(event.message!);
                  debugPrint('📨 Presence: $sender -> $content');
                  _handlePresenceMessage(sender, content);
                } catch (e) {
                  debugPrint('❌ Decode presence error: $e');
                }
              }
            }
          },
        );
        _listenerAdded = true;
      }

      // 订阅 Presence 频道
      final (status, _) = await _agoraService.rtmClient.subscribe(
        _presenceChannel,
      );
      if (status.error) {
        debugPrint('❌ Presence subscribe error: ${status.reason}');
        return;
      }

      _isSubscribed = true;
      debugPrint('✅ Presence subscribed: $_presenceChannel');

      // 发布自己的在线状态
      await setOnline(true);
    } catch (e) {
      debugPrint('❌ Presence init error: $e');
    }
  }

  /// 处理 Presence 消息
  void _handlePresenceMessage(String userId, String message) {
    try {
      // 消息格式: "online:true:live:false:room:xxx"
      final parts = message.split(':');
      if (parts.length >= 5) {
        final isOnline = parts[1] == 'true';
        final isLive = parts[3] == 'true';
        final liveRoomId = parts.length > 5 ? parts[5] : null;

        final presence = UserPresence(
          userId: userId,
          isOnline: isOnline,
          isLive: isLive,
          liveRoomId: liveRoomId?.isNotEmpty == true ? liveRoomId : null,
          updatedAt: DateTime.now(),
        );

        _presenceCache[userId] = presence;
        _presenceController.add(presence);

        // 更新好友服务中的状态
        friendService.updateFriendStatus(
          userId,
          isOnline: isOnline,
          isLive: isLive,
          liveRoomId: liveRoomId,
        );

        debugPrint(
          '👤 Presence updated: $userId online=$isOnline live=$isLive',
        );
      }
    } catch (e) {
      debugPrint('❌ Parse presence error: $e');
    }
  }

  /// 发布状态消息
  Future<void> _publishStatus({
    required bool isOnline,
    bool isLive = false,
    String? liveRoomId,
  }) async {
    if (!_isSubscribed) {
      debugPrint('⚠️ Presence not subscribed yet');
      return;
    }

    final message = 'online:$isOnline:live:$isLive:room:${liveRoomId ?? ''}';

    try {
      final (status, _) = await _agoraService.rtmClient.publish(
        _presenceChannel,
        message, // RTM 2.x 接受 String
      );
      if (status.error) {
        debugPrint('❌ Publish presence error: ${status.reason}');
      } else {
        debugPrint('📤 Published presence: $message');
      }
    } catch (e) {
      debugPrint('❌ Publish presence error: $e');
    }
  }

  /// 设置在线状态
  Future<void> setOnline(bool online) async {
    await _publishStatus(
      isOnline: online,
      isLive: _isLive,
      liveRoomId: _currentRoomId,
    );
  }

  /// 设置直播状态（主播调用）
  Future<void> setLiveStatus({required bool isLive, String? roomId}) async {
    _isLive = isLive;
    _currentRoomId = roomId;
    await _publishStatus(isOnline: true, isLive: isLive, liveRoomId: roomId);
    debugPrint('🔴 Live status: isLive=$isLive roomId=$roomId');
  }

  /// 获取用户状态
  UserPresence? getPresence(String userId) {
    return _presenceCache[userId];
  }

  /// 获取所有在线好友
  List<UserPresence> getOnlineFriends() {
    return _presenceCache.values.where((p) => p.isOnline).toList();
  }

  /// 获取正在直播的好友
  List<UserPresence> getLiveFriends() {
    return _presenceCache.values.where((p) => p.isLive).toList();
  }

  /// 离开频道
  Future<void> leave() async {
    try {
      await setOnline(false);
      await _agoraService.rtmClient.unsubscribe(_presenceChannel);
      _isSubscribed = false;
      debugPrint('👋 Left presence channel');
    } catch (e) {
      debugPrint('❌ Leave presence error: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _presenceController.close();
    _presenceCache.clear();
  }
}

/// 全局 PresenceService 实例
final presenceService = PresenceService();
