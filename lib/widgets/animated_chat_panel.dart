import 'package:chat_bottom_container/chat_bottom_container.dart';
import 'package:flutter/material.dart';
import 'package:live_app/widgets/chat_panel_controller.dart';
import 'package:live_app/widgets/animated_panel.dart';

export 'package:live_app/widgets/animated_panel.dart' show AnimationType;

class AnimatedChatPanel extends StatefulWidget {
  final ChatPanelController controller;
  final Widget Function(ChatPanelType type, double height) panelBuilder;
  final AnimationType animationType;
  final Duration duration;
  final Color? panelBgColor;

  const AnimatedChatPanel({
    super.key,
    required this.controller,
    required this.panelBuilder,
    this.animationType = AnimationType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.panelBgColor,
  });

  @override
  State<AnimatedChatPanel> createState() => _AnimatedChatPanelState();
}

class _AnimatedChatPanelState extends State<AnimatedChatPanel> {
  ChatPanelController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ChatBottomPanelContainer<ChatPanelType>(
      controller: controller.panelController,
      inputFocusNode: controller.focusNode,
      onPanelTypeChange: controller.onPanelTypeChange,
      panelBgColor: widget.panelBgColor ?? Colors.grey.shade100,
      otherPanelWidget: (type) {
        if (type == null) return const SizedBox.shrink();
        final height = controller.getPanelHeight(300);
        return AnimatedPanel(
          animationType: widget.animationType,
          duration: widget.duration,
          builder: (_) => SizedBox(
            key: ValueKey('panel_$type'),
            width: double.infinity,
            child: widget.panelBuilder(type, height),
          ),
        );
      },
    );
  }
}
