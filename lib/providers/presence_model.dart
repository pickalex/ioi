import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:live_app/models/friend.dart';
import 'package:live_app/services/friend_service.dart';
import 'package:live_app/services/presence_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'presence_model.g.dart';

@riverpod
class PresenceModel extends _$PresenceModel {
  StreamSubscription? _subscription;

  @override
  List<Friend> build() {
    debugPrint('🏗️ PresenceModel.build() called');
    debugPrint('📋 Friends count: ${friendService.friends.length}');
    for (var f in friendService.friends) {
      debugPrint('   - ${f.id}: ${f.username}');
    }

    _subscription = presenceService.presenceStream.listen((presence) {
      debugPrint('🔔 PresenceModel received presence update:');
      debugPrint('   userId: ${presence.userId}');
      debugPrint('   isLive: ${presence.isLive}');
      debugPrint('   isOnline: ${presence.isOnline}');
      updateFriendStatus(
        presence.userId,
        isOnline: presence.isOnline,
        isLive: presence.isLive,
        liveRoomId: presence.liveRoomId,
      );
    });

    ref.onDispose(() {
      debugPrint('🗑️ PresenceModel disposed');
      _subscription?.cancel();
    });

    return List.from(friendService.friends);
  }

  void updateFriendStatus(
    String friendId, {
    bool? isOnline,
    bool? isLive,
    String? liveRoomId,
  }) {
    debugPrint('🔄 updateFriendStatus: $friendId');
    debugPrint('   Current state count: ${state.length}');

    final index = state.indexWhere((friend) => friend.id == friendId);
    debugPrint('   Found at index: $index');

    if (index == -1) {
      debugPrint('   ❌ Friend not found in state!');
      return;
    }

    final oldFriend = state[index];
    final newFriend = oldFriend.copyWith(
      isOnline: isOnline ?? oldFriend.isOnline,
      isLive: isLive ?? oldFriend.isLive,
      liveRoomId: liveRoomId ?? oldFriend.liveRoomId,
    );

    debugPrint(
      '   Old: online=${oldFriend.isOnline}, live=${oldFriend.isLive}',
    );
    debugPrint(
      '   New: online=${newFriend.isOnline}, live=${newFriend.isLive}',
    );

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) newFriend else state[i],
    ];

    debugPrint('   ✅ State updated, new length: ${state.length}');
  }
}
