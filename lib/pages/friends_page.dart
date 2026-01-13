import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:live_app/providers/presence_model.dart';
import '../models/friend.dart';
import '../services/agora_service.dart';
import '../services/presence_service.dart';
import '../services/user_service.dart';

/// 好友列表页面
class FriendsPage extends HookConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(presenceModelProvider);

    // 初始化 Agora 和 Presence 服务
    useEffect(() {
      Future.microtask(() async {
        await AgoraService().initRtc();

        // 初始化 RTM (状态同步需要)
        final userId =
            userService.currentUser?.id ??
            'guest_${DateTime.now().millisecondsSinceEpoch}';
        await AgoraService().initRtm(userId);

        await presenceService.init();
      });
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('好友', style: TextStyle(color: Colors.white)),
      ),
      body: friends.isEmpty
          ? const Center(
              child: Text('还没有好友', style: TextStyle(color: Colors.white54)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return Card(
                  color: const Color(0xFF2A2A3E),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () {
                      context.push(
                        '/chat/${friend.id}?name=${friend.username}',
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1),
                      child: Text(
                        friend.username.isNotEmpty
                            ? friend.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      friend.username,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      friend.isLive
                          ? '🔴 直播中'
                          : (friend.isOnline ? '在线' : '离线'),
                      style: TextStyle(
                        color: friend.isLive
                            ? Colors.red
                            : (friend.isOnline ? Colors.green : Colors.grey),
                      ),
                    ),
                    trailing: friend.isLive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '进入直播',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
