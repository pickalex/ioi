import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend.dart';

/// 好友服务 - 管理好友列表
class FriendService {
  static const String _friendsKey = 'friends_list';
  static const String _requestsKey = 'friend_requests';

  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  SharedPreferences? _prefs;
  List<Friend> _friends = [];
  List<Friend> _requests = [];

  /// 好友列表
  List<Friend> get friends => List.unmodifiable(_friends);

  /// 好友请求列表
  List<Friend> get requests => List.unmodifiable(_requests);

  /// 初始化服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFriends();
    await _loadRequests();
  }

  /// 加载好友列表
  Future<void> _loadFriends() async {
    final json = _prefs?.getString(_friendsKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _friends = list.map((e) => Friend.fromJson(e)).toList();
      } catch (e) {
        _friends = [];
      }
    }
  }

  /// 加载好友请求
  Future<void> _loadRequests() async {
    final json = _prefs?.getString(_requestsKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _requests = list.map((e) => Friend.fromJson(e)).toList();
      } catch (e) {
        _requests = [];
      }
    }
  }

  /// 添加好友（发送请求）
  Future<void> addFriend(String userId, String username) async {
    // 检查是否已是好友
    if (_friends.any((f) => f.id == userId)) {
      return;
    }

    final friend = Friend(
      id: userId,
      username: username,
      status: FriendStatus.accepted, // 简化：直接添加为好友
    );

    _friends.add(friend);
    await _saveFriends();
  }

  /// 移除好友
  Future<void> removeFriend(String friendId) async {
    _friends.removeWhere((f) => f.id == friendId);
    await _saveFriends();
  }

  /// 更新好友状态
  Future<void> updateFriendStatus(
    String friendId, {
    bool? isOnline,
    bool? isLive,
    String? liveRoomId,
  }) async {
    final index = _friends.indexWhere((f) => f.id == friendId);
    if (index != -1) {
      _friends[index] = _friends[index].copyWith(
        isOnline: isOnline,
        isLive: isLive,
        liveRoomId: liveRoomId,
      );
      await _saveFriends();
    }
  }

  /// 保存好友列表
  Future<void> _saveFriends() async {
    final json = jsonEncode(_friends.map((f) => f.toJson()).toList());
    await _prefs?.setString(_friendsKey, json);
  }

  /// 清空数据（用于登出）
  Future<void> clear() async {
    _friends = [];
    _requests = [];
    await _prefs?.remove(_friendsKey);
    await _prefs?.remove(_requestsKey);
  }
}

/// 全局 FriendService 实例
final friendService = FriendService();
