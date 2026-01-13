import 'package:go_router/go_router.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:live_app/stock/pages/stock_quant_page.dart';
import 'package:live_app/pages/test/isolate_demo_page.dart';

// import 'package:flutter/services.dart';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:live_app/pages/landscape_live_page_3.dart';
// import 'package:live_app/pages/live_page_2.dart';
// import 'package:live_app/pages/test_keyboard_new.dart';
// import 'package:live_app/pages/test_animated_panel.dart';
// import 'package:live_app/pages/test/http_loading_page.dart';
// import 'pages/home_page.dart';
// import 'pages/live_page_3.dart';
// import 'pages/live_page.dart';
// import 'pages/popover_test_page.dart';
// import 'pages/friend_chat_page.dart';
// import 'pages/voice_room_page.dart';
// import 'pages/friends_page.dart';

final GoRouter router = GoRouter(
  observers: [FlutterSmartDialog.observer],

  routes: [
    GoRoute(path: '/', builder: (context, state) => const StockQuantPage()),

    // GoRoute(path: '/friends', builder: (context, state) => const FriendsPage()),
    // GoRoute(
    //   path: '/live/:channelId',
    //   builder: (context, state) {
    //     final channelId = state.pathParameters['channelId']!;
    //     final roleIndex =
    //         int.tryParse(state.uri.queryParameters['role'] ?? '1') ?? 1;
    //     final role = ClientRoleType.values[roleIndex];
    //     final playbackUrl = state.uri.queryParameters['playbackUrl'];
    //     return LivePage(
    //       channelName: channelId,
    //       role: role,
    //       playbackUrl: playbackUrl,
    //     );
    //   },
    // ),
    // GoRoute(
    //   path: '/test',
    //   builder: (context, state) => const PopoverTestPage(),
    // ),
    // GoRoute(
    //   path: '/chat/:friendId',
    //   builder: (context, state) {
    //     final friendId = state.pathParameters['friendId']!;
    //     final friendName = state.uri.queryParameters['name'] ?? 'Chat';
    //     return FriendChatPage(friendId: friendId, friendName: friendName);
    //   },
    // ),
    // GoRoute(
    //   path: '/voice_room/:channelId',
    //   builder: (context, state) {
    //     final channelId = state.pathParameters['channelId']!;
    //     return VoiceRoomPage(channelId: channelId, role: 'host');
    //   },
    // ),
    // GoRoute(
    //   path: '/live2/:channelId',
    //   builder: (context, state) {
    //     final channelName = state.pathParameters['channelId']!;
    //     return LivePage2(channelName: channelName);
    //   },
    // ),
    // GoRoute(
    //   path: '/live3/:channelId',
    //   builder: (context, state) {
    //     final channelName = state.pathParameters['channelId']!;
    //     return LivePage3(channelName: channelName);
    //   },
    // ),
    // GoRoute(
    //   name: '/live3/landscape',
    //   path: '/live3/landscape',
    //   pageBuilder: (context, state) {
    //     final extraMap = state.extra as Map<String, dynamic>;
    //     final channelName = extraMap['channelName'];
    //     final playerHandle = extraMap['playerHandle'];
    //     final isLive = extraMap['isLive'];
    //     final totalDuration = extraMap['totalDuration'];
    //     final initialPos = extraMap['initialPos'];
    //     final vodUrl = extraMap['vodUrl'];
    //     return CustomTransitionPage(
    //       key: state.pageKey,
    //       child: LandscapeLivePage3(
    //         channelName: channelName,
    //         initialIsLive: isLive,
    //         totalDuration: totalDuration,
    //         initialPos: initialPos,
    //         vodUrl: vodUrl,
    //         playerHandle: playerHandle,
    //       ),
    //       transitionsBuilder: (context, animation, secondaryAnimation, child) {
    //         // Plan A: 进入动画时强制旋转
    //         SystemChrome.setPreferredOrientations([
    //           DeviceOrientation.landscapeLeft,
    //           DeviceOrientation.landscapeRight,
    //         ]);
    //         return FadeTransition(opacity: animation, child: child);
    //       },
    //     );
    //   },
    // ),
    // GoRoute(
    //   path: '/test/keyboard_new',
    //   builder: (context, state) => const TestKeyboardNew(),
    // ),
    // GoRoute(
    //   path: '/test/animated_panel',
    //   builder: (context, state) => const TestAnimatedPanelPage(),
    // ),
    // GoRoute(
    //   path: '/test/http_loading',
    //   builder: (context, state) => const HttpLoadingPage(),
    // ),
   
  ],
);
