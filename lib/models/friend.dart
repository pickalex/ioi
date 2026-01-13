/// 好友模型
class Friend {
  final String id;
  final String username;
  final String? avatar;
  final FriendStatus status;
  final bool isOnline;
  final bool isLive;
  final String? liveRoomId;

  const Friend({
    required this.id,
    required this.username,
    this.avatar,
    this.status = FriendStatus.accepted,
    this.isOnline = false,
    this.isLive = false,
    this.liveRoomId,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      username: json['username'] as String,
      avatar: json['avatar'] as String?,
      status: FriendStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendStatus.pending,
      ),
      isOnline: json['isOnline'] as bool? ?? false,
      isLive: json['isLive'] as bool? ?? false,
      liveRoomId: json['liveRoomId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar': avatar,
      'status': status.name,
      'isOnline': isOnline,
      'isLive': isLive,
      'liveRoomId': liveRoomId,
    };
  }

  Friend copyWith({
    String? id,
    String? username,
    String? avatar,
    FriendStatus? status,
    bool? isOnline,
    bool? isLive,
    String? liveRoomId,
  }) {
    return Friend(
      id: id ?? this.id,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      isLive: isLive ?? this.isLive,
      liveRoomId: liveRoomId ?? this.liveRoomId,
    );
  }
}

/// 好友状态
enum FriendStatus {
  pending, // 等待确认
  accepted, // 已接受
  rejected, // 已拒绝
}
