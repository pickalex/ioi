import 'package:flutter/material.dart';
import '../widgets/cupertino_popover.dart';

class PopoverTestPage extends StatelessWidget {
  const PopoverTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Popover 边界测试'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 左上
          Positioned(
            left: 0,
            top: 0,
            child: _buildTestItem('左上 (大箭头)', arrowW: 30, arrowH: 15, gap: 12),
          ),
          // 右上
          Positioned(
            right: 0,
            top: 0,
            child: _buildTestItem('右上 (小尖角)', arrowW: 14, arrowH: 6, gap: 4),
          ),
          // 左下
          Positioned(
            left: 0,
            bottom: 0,
            child: _buildTestItem('左下 (远距离)', gap: 24),
          ),
          // 右下
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildTestItem('右下 (超宽箭头)', arrowW: 40, arrowH: 8, gap: 8),
          ),
          // 正中
          Center(child: _buildTestItem('正中 (默认)')),
        ],
      ),
    );
  }

  Widget _buildTestItem(
    String label, {
    double? arrowW,
    double? arrowH,
    double? gap,
  }) {
    return CupertinoPopover(
      backgroundColor: const Color(0xFF222222),
      borderRadius: 8.0,
      arrowWidth: arrowW ?? 20.0,
      arrowHeight: arrowH ?? 10.0,
      verticalGap: gap ?? 12.0,
      popoverBuilder: (context, controller) => Container(
        // constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label 边界对齐逻辑测试。这是一段很长很长的文本，用来测试气泡内部的自动换行逻辑是否正常工作。即使在屏幕边缘，内容也应该被限制在安全区域内。',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
          textAlign: TextAlign.start,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: Text(label, style: const TextStyle(color: Colors.blue)),
      ),
    );
  }
}
