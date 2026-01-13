import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:live_app/services/permission_utils.dart';

import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../models/live_room.dart';
import '../blocs/home_bloc.dart';
import '../widgets/cupertino_popover.dart';
import '../widgets/custom_bottom_bar.dart';
import '../main.dart';
import '../utils/debounce_throttle.dart';
import '../utils/date_util.dart';
import '../services/dialog_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controllers
  late final ScrollController _scrollController;
  late final SliverObserverController _observerController;
  final GlobalKey _masonryGridKey = GlobalKey();

  // State
  List<int> _visibleIndices = [];
  DateTime _lastInteractionTime = DateTime.now();
  int _selectedIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _observerController = SliverObserverController(
      controller: _scrollController,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer(HomeBloc bloc) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Use captured bloc instance
      final state = bloc.state;
      final activeRoomIndex = state.activeRoomIndex;

      if (DateTime.now().difference(_lastInteractionTime).inSeconds >= 3) {
        if (_visibleIndices.isNotEmpty) {
          int currentIndexInVisible = _visibleIndices.indexOf(activeRoomIndex);
          int nextIndex;

          if (currentIndexInVisible == -1) {
            nextIndex = _visibleIndices.first;
          } else {
            nextIndex =
                _visibleIndices[(currentIndexInVisible + 1) %
                    _visibleIndices.length];
          }

          if (activeRoomIndex != nextIndex) {
            bloc.add(HomeUpdateActiveIndexEvent(nextIndex));
          }
        }
      }
    });
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      _lastInteractionTime = DateTime.now();
    }
  }

  void _onObserveAll(Map<BuildContext, ObserveModel> resultMap) {
    Throttler.run(
      tag: 'home_grid_observe',
      duration: const Duration(milliseconds: 100),
      action: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (final result in resultMap.values) {
            if (result is GridViewObserveModel) {
              final newVisibleIndices = result.displayingChildModelList
                  .where((model) => model.displayPercentage > 0.5)
                  .map((e) => e.index)
                  .toList();

              if (newVisibleIndices.length != _visibleIndices.length ||
                  !newVisibleIndices.every(
                    (element) => _visibleIndices.contains(element),
                  )) {
                _visibleIndices = newVisibleIndices;
              }
            }
          }
        });
      },
    );
  }

  // Helper functions
  void _toggleLanguage() {
    if (appLocale.value.languageCode == 'zh') {
      appLocale.value = const Locale('en');
      SmartDialog.showToast('Language switched to English');
    } else {
      appLocale.value = const Locale('zh');
      SmartDialog.showToast('语言已切换为中文');
    }
  }

  Future<void> _onJoin(LiveRoom room, List<LiveRoom> rooms) async {
    final index = rooms.indexOf(room);
    final channelId = index == 0 ? 'test_channel' : room.id;

    final ret = await PermissionUtils.requestMultipleWithMask(
      permissions: [Permission.camera, Permission.microphone],
      description: '我们将使用相机和麦克风权限用于视频通话和直播。',
    );
    if (mounted &&
        ret[Permission.camera]?.isGranted == true &&
        ret[Permission.microphone]?.isGranted == true) {
      context.push(
        '/live/$channelId?role=${ClientRoleType.clientRoleAudience.index}',
      );
    }
  }

  Future<void> _handleGoLive() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '开始直播',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  Icons.videocam_rounded,
                  '视频直播',
                  Colors.blueAccent,
                  () async {
                    // 1. Capture the router before popping the bottom sheet
                    final router = GoRouter.of(context);
                    // 2. Close bottom sheet
                    router.pop();

                    final ret = await PermissionUtils.requestMultipleWithMask(
                      permissions: [Permission.camera, Permission.microphone],
                      description: '我们将使用相机和麦克风权限用于视频通话和直播。',
                    );
                    if (ret[Permission.camera]?.isGranted == true &&
                        ret[Permission.microphone]?.isGranted == true) {
                      router.push(
                        '/live/test_channel?role=${ClientRoleType.clientRoleBroadcaster.index}',
                      );
                    }
                  },
                ),
                _buildActionButton(
                  context,
                  Icons.mic_rounded,
                  '语音直播',
                  Colors.pinkAccent,
                  () {
                    GoRouter.of(context).pop();
                    context.push('/voice_room/voice_demo');
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = HomeBloc()..add(HomeLoadEvent());
        // Do not start timer in create, it's safer in the builder below or initState logic
        return bloc;
      },
      child: Builder(
        builder: (context) {
          // Now context has HomeBloc
          final bloc = context.read<HomeBloc>();
          if (_timer == null || !_timer!.isActive) {
            _startTimer(bloc);
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            extendBody: true,
            appBar: AppBar(
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              elevation: 0,
              title: Text(
                AppLocalizations.of(context)!.appTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.language),
                  onPressed: _toggleLanguage,
                ),
                _buildMoreMenu(context),
                const SizedBox(width: 8),
              ],
            ),
            bottomNavigationBar: CustomHomeBottomBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
                if (index == 1) {
                  context.push('/friends');
                }
              },
              onGoLive: _handleGoLive,
            ),
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'test_loading',
                    backgroundColor: Colors.orange,
                    onPressed: () async {
                      // 测试异步任务 Loading
                      await DialogService.runWithLoading(
                        msg: '正在模拟异步任务...',
                        task: Future.delayed(
                          const Duration(seconds: 3),
                          () => 'Done',
                        ),
                      );
                    },
                    child: const Icon(Icons.refresh, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    heroTag: 'test_notify',
                    backgroundColor: Colors.blue,
                    onPressed: () {
                      DialogService.showNotification(
                        '收到一条新通知 ${DateTime.now().second}',
                      );
                    },
                    child: const Icon(Icons.add_alert, color: Colors.white),
                  ),
                ],
              ),
            ),
            body: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _onScrollNotification(notification);
                return false;
              },
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  // Print for debugging rebuilds
                  print(
                    '<<<<<<<<<<<HomePage Rebuild: ${DateTime.now().dateTimeString}',
                  );

                  final rooms = state.rooms;
                  final activeRoomIndex = state.activeRoomIndex;

                  return SliverViewObserver(
                    controller: _observerController,
                    sliverContexts: () {
                      return _masonryGridKey.currentContext != null
                          ? [_masonryGridKey.currentContext!]
                          : [];
                    },
                    extendedHandleObserve: (context) {
                      final renderObj = ObserverUtils.findRenderObject(context);
                      if (renderObj is RenderSliverMultiBoxAdaptor) {
                        return ObserverCore.handleGridObserve(
                          context: context,
                          fetchLeadingOffset: () => 0,
                        );
                      }
                      return null;
                    },
                    onObserveAll: _onObserveAll,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        _buildBanner(),
                        _buildCategoryBar(),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: Builder(
                            builder: (context) {
                              return state.isLoading && rooms.isEmpty
                                  ? const SliverToBoxAdapter(
                                      child: Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: CupertinoActivityIndicator(),
                                        ),
                                      ),
                                    )
                                  : SliverMasonryGrid.count(
                                      key: _masonryGridKey,
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      itemBuilder: (context, index) {
                                        final room = rooms[index];
                                        return _RoomCard(
                                          room: room,
                                          isActive: index == activeRoomIndex,
                                          onTap: () => _onJoin(room, rooms),
                                        );
                                      },
                                      childCount: rooms.length,
                                    );
                            },
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context) {
    return CupertinoPopover(
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Icon(Icons.add_circle_outline),
      ),
      popoverBuilder: (context, controller) {
        return Container(
          width: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSimpleMenuItem(Icons.videocam, '发起直播', controller, () async {
                final router = GoRouter.of(context);
                await [Permission.camera, Permission.microphone].request();
                router.push(
                  '/live/my_channel?role=${ClientRoleType.clientRoleBroadcaster.index}',
                );
              }),
              const Divider(height: 1),
              _buildSimpleMenuItem(Icons.help_outline, '帮助', controller, () {}),
              _buildSimpleMenuItem(Icons.info_outline, '关于', controller, () {
                context.push('/test');
              }),
              _buildSimpleMenuItem(Icons.info_outline, '动画测试', controller, () {
                context.push('/test/animated_panel');
              }),
              _buildSimpleMenuItem(Icons.science, '官方Demo', controller, () {
                context.push('/live2/123456');
              }),
              _buildSimpleMenuItem(Icons.http, 'Http Loading', controller, () {
                context.push('/test/http_loading');
              }),
              _buildSimpleMenuItem(Icons.query_stats, '量化交易', controller, () {
                context.push('/stock_quant');
              }),
            ],
          ),
        );
      },
      backgroundColor: Colors.black,
    );
  }

  Widget _buildSimpleMenuItem(
    IconData icon,
    String title,
    CupertinoPopoverController controller,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        controller.hide();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return SliverToBoxAdapter(
      child: Container(
        height: 150,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => context.push('/stock_quant'),
          child: Stack(
            children: [
              const Center(
                child: Text(
                  '量化智能分析',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '立即体验 >',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SliverToBoxAdapter(
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: ['全部', '热门', '游戏', '娱乐', '颜值', '户外'].map((e) {
            return Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: e == '全部' ? Colors.blueAccent : Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  e,
                  style: TextStyle(
                    color: e == '全部' ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final LiveRoom room;
  final bool isActive;
  final VoidCallback onTap;

  const _RoomCard({
    required this.room,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: Colors.blueAccent, width: 4)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: room.aspectRatio,
                  child: Image.network(
                    room.coverUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 500,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey[300]),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${room.viewerCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.broadcasterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
