import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// iOS 风格返回按钮 - 使用 < 箭头，无水波纹
class IosBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const IosBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.black;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 44,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      child: Icon(Icons.arrow_back_ios_new, size: 20, color: iconColor),
    );
  }
}

/// 带标题居中的 iOS 风格 AppBar
class IosAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final Color? backgroundColor;

  const IosAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return AppBar(
      title: Text(title),
      centerTitle: true,
      backgroundColor: backgroundColor ?? Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading:
          leading ??
          (automaticallyImplyLeading && canPop ? const IosBackButton() : null),
      actions: actions,
    );
  }
}
