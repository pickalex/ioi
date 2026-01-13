class LiveRoom {
  final String id;
  final String title;
  final String broadcasterName;
  final String coverUrl;
  final int viewerCount;
  final double aspectRatio;
  final String? playbackUrl;

  LiveRoom({
    required this.id,
    required this.title,
    required this.broadcasterName,
    required this.coverUrl,
    required this.viewerCount,
    required this.aspectRatio,
    this.playbackUrl,
  });

  factory LiveRoom.fromJson(Map<String, dynamic> json) {
    return LiveRoom(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      broadcasterName:
          json['broadcasterName'] ??
          json['broadcaster_name'] ??
          '主播${json['userId'] ?? json['id'] ?? ""}',
      coverUrl:
          json['coverUrl'] ??
          json['cover_url'] ??
          'https://placehold.co/400x500/png?text=Room${json['id'] ?? ""}',
      viewerCount:
          json['viewerCount'] ??
          json['viewer_count'] ??
          ((json['id'] as int? ?? 0) * 100),
      aspectRatio: (json['aspectRatio'] ?? json['aspect_ratio'] ?? 0.8)
          .toDouble(),
      playbackUrl: json['playbackUrl'] ?? json['playback_url'],
    );
  }
}

final List<LiveRoom> mockRooms = List.generate(50, (index) {
  final titles = [
    '深夜情感电台 🌙',
    '大神带你上铂金！',
    '户外阳光直播',
    '技术流：手搓App',
    '萌宠频道：三只猫',
    '美食探店：火锅',
    '尤克里里弹唱',
    '健身打卡第30天',
    '沉浸式学习中...',
    '午后茶点时光',
    '跟我一起云旅行',
    '最强中单教学',
  ];
  final names = ['小美', '阿强', '老炮', '码农小哥', '温柔姐', '吃货队长', '琴师', '健美达人'];

  // 随机宽高比模拟瀑布流高度差异
  final width = 400;
  final height = 400 + (index % 3) * 100 + (index % 2) * 50;
  final double aspectRatio = width / height;

  String? playbackUrl;
  // 前3个房间模拟回放
  if (index < 3) {
    playbackUrl = 'https://vjs.zencdn.net/v/oceans.mp4';
  }

  return LiveRoom(
    id: 'room_$index',
    title:
        '${titles[index % titles.length]} #$index${playbackUrl != null ? " (回放)" : ""}',
    broadcasterName: names[index % names.length],
    coverUrl: 'https://placehold.co/${width}x${height}/png?text=Room$index',
    viewerCount: 100 + index * 150 + (index % 7) * 33,
    aspectRatio: aspectRatio,
    playbackUrl: playbackUrl,
  );
});
