import 'package:flutter/material.dart';
import 'package:live_app/widgets/animated_panel.dart';

class TestAnimatedPanelPage extends StatefulWidget {
  const TestAnimatedPanelPage({super.key});

  @override
  State<TestAnimatedPanelPage> createState() => _TestAnimatedPanelPageState();
}

class _TestAnimatedPanelPageState extends State<TestAnimatedPanelPage> {
  AnimationType _animationType = AnimationType.fade;
  int _panelIndex = 0;

  final _panels = [
    {'color': Colors.red, 'icon': Icons.home, 'label': '首页'},
    {'color': Colors.blue, 'icon': Icons.search, 'label': '搜索'},
    {'color': Colors.green, 'icon': Icons.person, 'label': '我的'},
    {'color': Colors.orange, 'icon': Icons.settings, 'label': '设置'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimatedPanel 测试'),
        actions: [
          PopupMenuButton<AnimationType>(
            icon: const Icon(Icons.animation),
            tooltip: '选择动画',
            onSelected: (type) => setState(() => _animationType = type),
            itemBuilder: (context) => AnimationType.values.map((type) {
              return PopupMenuItem(
                value: type,
                child: Row(
                  children: [
                    if (type == _animationType)
                      const Icon(Icons.check, size: 18, color: Colors.blue),
                    if (type != _animationType) const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(_getAnimationName(type)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 动画类型显示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Text(
              '当前动画: ${_getAnimationName(_animationType)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 切换按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_panels.length, (index) {
                final panel = _panels[index];
                final isSelected = _panelIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _panelIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (panel['color'] as Color)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      panel['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black54,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // AnimatedPanel 展示区
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedPanel(
                animationType: _animationType,
                duration: const Duration(milliseconds: 400),
                builder: (context) => _buildPanelContent(_panelIndex),
              ),
            ),
          ),

          // 快速切换按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _panelIndex = (_panelIndex - 1) % _panels.length;
                      if (_panelIndex < 0) _panelIndex = _panels.length - 1;
                    }),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('上一个'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _panelIndex = (_panelIndex + 1) % _panels.length;
                    }),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('下一个'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(int index) {
    final panel = _panels[index];
    return Container(
      key: ValueKey('panel_$index'),
      decoration: BoxDecoration(
        color: (panel['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panel['color'] as Color, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              panel['icon'] as IconData,
              size: 80,
              color: panel['color'] as Color,
            ),
            const SizedBox(height: 16),
            Text(
              panel['label'] as String,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: panel['color'] as Color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '面板 ${index + 1}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _getAnimationName(AnimationType type) {
    const names = {
      AnimationType.none: '无动画',
      AnimationType.fade: '淡入淡出',
      AnimationType.flipX: '水平翻转',
      AnimationType.flipY: '垂直翻转',
      AnimationType.slideUp: '向上滑动',
      AnimationType.slideDown: '向下滑动',
      AnimationType.slideLeft: '向左滑动',
      AnimationType.slideRight: '向右滑动',
      AnimationType.zoomIn: '放大进入',
      AnimationType.zoomOut: '缩小进入',
    };
    return names[type] ?? type.name;
  }
}
