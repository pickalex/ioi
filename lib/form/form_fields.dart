import 'package:flutter/cupertino.dart' hide FormFieldState;
import 'package:flutter/material.dart' hide FormFieldState;
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'form_state.dart';

/// 表单常量配置（默认值）
class FormFieldDefaults {
  static const double iconSize = 20.0;
  static const double labelWidth = 100.0;
  static const double horizontalPadding = 16.0;
  static const double verticalPadding = 12.0;
  static const double spacing = 12.0;
  static const double minRowHeight = 50.0;
}

/// 分割线类型
enum FormFieldBorderType {
  full, // 包含 Label (左右 Padding)
  half, // 一半：不包含 Label (从 Input 开始)
  none // 无分割线
}

/// 清除按钮模式
enum FormClearButtonMode { never, whileEditing, always }

/// 文本显示模式
enum FormTextDisplayMode {
  wrap, // 换行
  ellipsisEnd, // 结尾省略
  ellipsisStart // 头部省略
}

/// 星号位置
enum AsteriskPosition {
  beforeIcon, // 在 icon 左边（默认）
  afterIcon, // 在 icon 和 label 之间
}

/// ============================================================================
/// 表单全局配置 (InheritedWidget)
/// ============================================================================
///
/// 使用方式:
/// ```dart
/// FormFieldConfig(
///   rowHeight: 56,
///   asteriskPosition: AsteriskPosition.beforeIcon,
///   child: Column(children: [
///     FormTextField(...),
///     FormPickerField(...),
///   ]),
/// )
/// ```
///
/// 优先级: Field 单独配置 > 全局配置 > FormFieldDefaults
class FormFieldConfig extends InheritedWidget {
  // 布局配置
  final double? iconSize;
  final double? labelWidth;
  final double? horizontalPadding;
  final double? verticalPadding;
  final double? spacing;
  final double? rowHeight;
  final int? labelMaxLines;

  // 分割线配置
  final FormFieldBorderType? borderType;
  final Color? dividerColor;

  // 样式配置
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final TextStyle? pickerTextStyle;
  final TextStyle? pickerPlaceholderStyle;
  final TextAlign? textAlign;

  // 必填标记配置
  final AsteriskPosition? asteriskPosition;
  final Color? asteriskColor;

  // Picker 按钮配置
  final String? pickerCancelLabel;
  final String? pickerConfirmLabel;
  final TextStyle? pickerCancelTextStyle;
  final TextStyle? pickerConfirmTextStyle;

  const FormFieldConfig({
    super.key,
    required super.child,
    this.iconSize,
    this.labelWidth,
    this.horizontalPadding,
    this.verticalPadding,
    this.spacing,
    this.rowHeight,
    this.labelMaxLines,
    this.borderType,
    this.dividerColor,
    this.labelStyle,
    this.textStyle,
    this.placeholderStyle,
    this.pickerTextStyle,
    this.pickerPlaceholderStyle,
    this.asteriskPosition,
    this.asteriskColor,
    this.pickerCancelLabel,
    this.pickerConfirmLabel,
    this.pickerCancelTextStyle,
    this.pickerConfirmTextStyle,
    this.textAlign,
  });

  /// 获取配置，可能为 null
  static FormFieldConfig? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FormFieldConfig>();
  }

  /// 获取配置（非空，如果没有则创建一个空配置）
  static FormFieldConfig of(BuildContext context) {
    final config = maybeOf(context);
    // 返回一个空配置作为 fallback
    return config ?? const FormFieldConfig(child: SizedBox.shrink());
  }

  @override
  bool updateShouldNotify(FormFieldConfig oldWidget) {
    return iconSize != oldWidget.iconSize ||
        labelWidth != oldWidget.labelWidth ||
        horizontalPadding != oldWidget.horizontalPadding ||
        verticalPadding != oldWidget.verticalPadding ||
        spacing != oldWidget.spacing ||
        rowHeight != oldWidget.rowHeight ||
        labelMaxLines != oldWidget.labelMaxLines ||
        borderType != oldWidget.borderType ||
        dividerColor != oldWidget.dividerColor ||
        labelStyle != oldWidget.labelStyle ||
        textStyle != oldWidget.textStyle ||
        placeholderStyle != oldWidget.placeholderStyle ||
        pickerTextStyle != oldWidget.pickerTextStyle ||
        pickerPlaceholderStyle != oldWidget.pickerPlaceholderStyle ||
        asteriskPosition != oldWidget.asteriskPosition ||
        asteriskColor != oldWidget.asteriskColor ||
        pickerCancelLabel != oldWidget.pickerCancelLabel ||
        pickerConfirmLabel != oldWidget.pickerConfirmLabel ||
        pickerCancelTextStyle != oldWidget.pickerCancelTextStyle ||
        pickerConfirmTextStyle != oldWidget.pickerConfirmTextStyle ||
        textAlign != oldWidget.textAlign;
  }
}

/// 通用分割线
class FormDivider extends StatelessWidget {
  final FormFieldBorderType? type;
  final Color? color;

  const FormDivider({
    super.key,
    this.type,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final config = FormFieldConfig.maybeOf(context);
    final effectiveType =
        type ?? config?.borderType ?? FormFieldBorderType.full;

    if (effectiveType == FormFieldBorderType.none)
      return const SizedBox.shrink();

    final hPadding =
        config?.horizontalPadding ?? FormFieldDefaults.horizontalPadding;
    final labelW = config?.labelWidth ?? FormFieldDefaults.labelWidth;
    final sp = config?.spacing ?? FormFieldDefaults.spacing;

    double startPadding = 0;
    if (effectiveType == FormFieldBorderType.full) {
      startPadding = hPadding;
    } else if (effectiveType == FormFieldBorderType.half) {
      startPadding = hPadding + labelW + sp;
    }

    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: startPadding,
      endIndent: hPadding,
      color: color ?? config?.dividerColor ?? Theme.of(context).dividerColor,
    );
  }
}

/// 标签区域
class FormFieldLabelSection extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isRequired;
  final TextStyle? labelStyle;
  final AsteriskPosition? asteriskPosition;
  final Color? asteriskColor;
  final int? maxLines;

  /// 帮助构建器，在 label 后面显示（如 ? 图标）
  final Widget Function(BuildContext context)? helperBuilder;

  const FormFieldLabelSection({
    super.key,
    required this.label,
    this.icon,
    this.isRequired = false,
    this.labelStyle,
    this.asteriskPosition,
    this.asteriskColor,
    this.maxLines,
    this.helperBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = FormFieldConfig.maybeOf(context);

    // 样式优先级: 参数 > config > theme
    final effectiveLabelStyle =
        labelStyle ?? config?.labelStyle ?? theme.textTheme.bodyMedium;
    final effectiveIconSize = config?.iconSize ?? FormFieldDefaults.iconSize;
    final effectiveLabelWidth =
        config?.labelWidth ?? FormFieldDefaults.labelWidth;
    final effectiveAsteriskPosition = asteriskPosition ??
        config?.asteriskPosition ??
        AsteriskPosition.beforeIcon;
    final effectiveAsteriskColor =
        asteriskColor ?? config?.asteriskColor ?? theme.colorScheme.error;
    final effectiveMaxLines = maxLines ?? config?.labelMaxLines ?? 1;

    final labelColor = effectiveLabelStyle?.color ??
        (isRequired
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant);

    // 构建星号 Widget
    Widget? asteriskWidget;
    if (isRequired) {
      asteriskWidget = Text(
        "* ",
        style: effectiveLabelStyle?.copyWith(color: effectiveAsteriskColor),
      );
    }

    return SizedBox(
      width: effectiveLabelWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 星号在 icon 前面
          if (isRequired &&
              effectiveAsteriskPosition == AsteriskPosition.beforeIcon)
            asteriskWidget!,

          // Icon
          if (icon != null) ...[
            Icon(
              icon,
              size: effectiveIconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
          ],

          // Label (带可选的星号在文字前)
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  // 星号在 icon 后面 (label 前)
                  if (isRequired &&
                      effectiveAsteriskPosition == AsteriskPosition.afterIcon)
                    TextSpan(
                      text: "* ",
                      style: effectiveLabelStyle?.copyWith(
                          color: effectiveAsteriskColor),
                    ),
                  TextSpan(
                    text: label,
                    style: effectiveLabelStyle?.copyWith(color: labelColor),
                  ),
                ],
              ),
              maxLines: effectiveMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Helper (如 ? 图标)
          if (helperBuilder != null) ...[
            const SizedBox(width: 4),
            helperBuilder!(context),
          ],
        ],
      ),
    );
  }
}

/// 通用文本输入框
class FormTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final int? maxLength;
  final bool showCharCount;
  final bool enabled;

  /// 错误信息，支持 String 或 String? Function(BuildContext)
  final dynamic errorMessage;
  final int maxLines;
  final int minLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final FormFieldBorderType borderType;
  final FormClearButtonMode clearButtonMode;
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final double? rowHeight;
  final TextAlign? textAlign;

  /// 输入格式化器列表
  final List<TextInputFormatter>? inputFormatters;

  /// 创建时回调，暴露 controller, focusNode, showPicker (文本框无 showPicker)
  final void Function(TextEditingController controller, FocusNode focusNode,
      VoidCallback? showPicker)? onCreate;

  /// 可选的 FormFieldState 绑定，自动绑定 controller 和 focusNode
  final FormFieldState<String>? fieldState;

  /// 信息提示构建器，显示在横线上方（错误信息显示在 info 上方）
  final Widget Function(BuildContext context)? infoBuilder;

  /// 帮助构建器，在 label 后面显示（如 ? 图标）
  final Widget Function(BuildContext context)? helperBuilder;

  final int? labelMaxLines;

  const FormTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.placeholder = "",
    this.icon,
    this.isRequired = false,
    this.maxLength,
    this.showCharCount = true,
    this.enabled = true,
    this.errorMessage,
    this.maxLines = 1,
    this.minLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.borderType = FormFieldBorderType.full,
    this.clearButtonMode = FormClearButtonMode.always,
    this.labelStyle,
    this.textStyle,
    this.placeholderStyle,
    this.rowHeight,
    this.inputFormatters,
    this.onCreate,
    this.fieldState,
    this.infoBuilder,
    this.helperBuilder,
    this.labelMaxLines,
    this.textAlign,
  });

  /// 状态绑定构造函数
  /// 直接绑定 [FormFieldState]，无需手动传递 [value] 和 [onValueChange]
  /// 且内部会自动监听状态变化，无需包裹 [ListenableBuilder]
  FormTextField.state({
    Key? key,
    required FormFieldState<String> state,
    required this.label,
    this.placeholder = "",
    this.icon,
    this.isRequired = false,
    this.maxLength,
    this.showCharCount = true,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.borderType = FormFieldBorderType.full,
    this.clearButtonMode = FormClearButtonMode.always,
    this.labelStyle,
    this.textStyle,
    this.placeholderStyle,
    this.rowHeight,
    this.inputFormatters,
    this.onCreate,
    this.infoBuilder,
    this.helperBuilder,
    this.labelMaxLines,
    this.textAlign,
  })  : value = state.value,
        onValueChange = state.didChange,
        fieldState = state,
        errorMessage = null, // state 内部监听会自动处理
        super(key: key ?? state.key);

  @override
  State<FormTextField> createState() => _FormTextFieldState();
}

class _FormTextFieldState extends State<FormTextField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      // 标记交互状态
      if (!_focusNode.hasFocus) {
        widget.fieldState?.didInteract();
      }
    });

    // 绑定 State 监听
    widget.fieldState?.addListener(_onFieldStateChanged);

    // 绑定 controller 和 focusNode 到 state
    if (widget.fieldState != null) {
      // 这里的 onCreate Logic 可以保留，也可以让 State 直接持有
      // 目前 FormFieldState 没有直接持有 controller，而是通过回调暴露
    }

    widget.onCreate?.call(_controller, _focusNode, null);
  }

  @override
  void didUpdateWidget(covariant FormTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      // 当外部 value 变化 (且不等于当前输入框内容) 时，更新输入框
      // 避免光标跳动: 只有当确实不一致时才更新
      // 更好的做法是保持 selection，但这里简单处理只是 update text
      // 如果正在输入中，通常 external value update 是由 internal onChanged 触发的，
      // 这种情况下 widget.value == _controller.text，不会触发这里。
      // 只有当 external value 真的变了 (例如 reset) 才会触发。
      _controller.text = widget.value;
      // 重新设置光标位置到最后，防止重置后光标错位 (可选)
      // _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }

    if (widget.fieldState != oldWidget.fieldState) {
      oldWidget.fieldState?.removeListener(_onFieldStateChanged);
      widget.fieldState?.addListener(_onFieldStateChanged);
    }
  }

  @override
  void dispose() {
    widget.fieldState?.removeListener(_onFieldStateChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFieldStateChanged() {
    // 当 State 变化时 (例如 reset, 或者 value changed from outside, 或者 error message changed)
    // 触发 rebuild 以更新 error message 和 potential value changes
    if (mounted) {
      setState(() {
        // 如果 value 变了，同步到 controller
        if (widget.fieldState != null &&
            widget.fieldState!.value != _controller.text) {
          _controller.text = widget.fieldState!.value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = FormFieldConfig.maybeOf(context);

    // 优先级: widget > config > defaults
    final effectiveRowHeight =
        widget.rowHeight ?? config?.rowHeight ?? FormFieldDefaults.minRowHeight;
    final effectiveHPadding =
        config?.horizontalPadding ?? FormFieldDefaults.horizontalPadding;
    final effectiveSpacing = config?.spacing ?? FormFieldDefaults.spacing;
    final effectiveTextStyle =
        widget.textStyle ?? config?.textStyle ?? theme.textTheme.bodyMedium;
    final effectivePlaceholderStyle = widget.placeholderStyle ??
        config?.placeholderStyle ??
        theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5));

    // 错误信息逻辑
    String? resolvedErrorMessage;
    if (widget.errorMessage is String) {
      resolvedErrorMessage = widget.errorMessage;
    } else if (widget.errorMessage is String? Function(BuildContext)) {
      resolvedErrorMessage =
          (widget.errorMessage as String? Function(BuildContext))(context);
    } else if (widget.errorMessage is String? Function()) {
      resolvedErrorMessage = (widget.errorMessage as String? Function())();
    }

    final effectiveErrorMessage = resolvedErrorMessage ??
        (widget.fieldState?.hasInteracted == true
            ? widget.fieldState?.errorMessage
            : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;

    // 显示清除按钮逻辑
    bool showClear = false;
    if (widget.value.isNotEmpty) {
      switch (widget.clearButtonMode) {
        case FormClearButtonMode.never:
          showClear = false;
          break;
        case FormClearButtonMode.whileEditing:
          showClear = _isFocused;
          break;
        case FormClearButtonMode.always:
          showClear = true;
          break;
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(minHeight: effectiveRowHeight),
              padding: EdgeInsets.symmetric(
                horizontal: effectiveHPadding,
                vertical: 4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Label
                  FormFieldLabelSection(
                    label: widget.label,
                    icon: widget.icon,
                    isRequired: widget.isRequired,
                    labelStyle: widget.labelStyle,
                    helperBuilder: widget.helperBuilder,
                    maxLines: widget.labelMaxLines,
                  ),
                  SizedBox(width: effectiveSpacing),

                  // Input
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      keyboardType: widget.keyboardType,
                      maxLines: widget.maxLines,
                      minLines: widget.minLines,
                      obscureText: widget.obscureText,
                      maxLength: widget.maxLength,
                      inputFormatters: widget.inputFormatters,
                      buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      style: effectiveTextStyle,
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: effectivePlaceholderStyle,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      textAlign: widget.textAlign ??
                          config?.textAlign ??
                          TextAlign.start,
                      onChanged: (val) {
                        widget.onValueChange(val);
                      },
                    ),
                  ),

                  // Clear Button (与 Picker 的清除按钮对齐)
                  if (showClear && widget.enabled) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        widget.onValueChange("");
                        _controller.clear();
                      },
                      child: Icon(
                        Icons.cancel,
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                    // 占位间距，与 Picker 的图标宽度对齐 (8px gap + 20px icon)
                    const SizedBox(width: 28),
                  ],
                ],
              ),
            ),
            // infoBuilder (如果有，在输入行下方)
            if (widget.infoBuilder != null) widget.infoBuilder!(context),
            // divider 在最下面
            FormDivider(
              type: widget.borderType,
              color: hasError ? theme.colorScheme.error.withOpacity(0.5) : null,
            ),
          ],
        ),
        // 错误信息位置：有 infoBuilder 时放在 rowHeight 区域，没有时贴着线
        if (hasError)
          Positioned(
            // 有 infoBuilder: 放在 rowHeight 区域底部 (距离 Container 底部)
            // 无 infoBuilder: 贴着线 (bottom: 2)
            bottom: widget.infoBuilder != null ? null : 2,
            top: widget.infoBuilder != null ? effectiveRowHeight - 18 : null,
            right: effectiveHPadding,
            child: Text(
              effectiveErrorMessage,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
              ),
            ),
          )
        // 字数统计 (无错误时显示)
        else if (widget.maxLength != null &&
            widget.showCharCount &&
            widget.value.isNotEmpty)
          Positioned(
            bottom: widget.infoBuilder != null ? null : 2,
            top: widget.infoBuilder != null ? effectiveRowHeight - 18 : null,
            right: effectiveHPadding,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "${widget.value.length}",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.value.length > widget.maxLength!
                          ? theme.colorScheme.error
                          : Colors.teal.shade300,
                      fontSize: 10,
                    ),
                  ),
                  TextSpan(
                    text: "/${widget.maxLength}",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 数字输入框
class FormNumberField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final bool isDecimal;
  final int maxDecimalPlaces;
  final double? maxValue;
  final bool allowNegative;

  /// 错误信息，支持 String 或 String? Function(BuildContext) 或 String? Function()
  final dynamic errorMessage;
  final FormFieldBorderType borderType;

  FormNumberField({
    Key? key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.placeholder = "请输入数字",
    this.icon,
    this.isRequired = false,
    this.isDecimal = false,
    this.maxDecimalPlaces = 2,
    this.maxValue,
    this.allowNegative = false,
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
    this.fieldState,
  }) : super(key: key ?? fieldState?.key);

  /// 状态绑定构造函数
  FormNumberField.state({
    Key? key,
    required FormFieldState<String> state,
    required this.label,
    this.placeholder = "请输入数字",
    this.icon,
    this.isRequired = false,
    this.isDecimal = false,
    this.maxDecimalPlaces = 2,
    this.maxValue,
    this.allowNegative = false,
    this.borderType = FormFieldBorderType.full,
  })  : value = state.value,
        onValueChange = state.didChange,
        fieldState = state,
        errorMessage = null,
        super(key: key ?? state.key);

  /// 可选的 FormFieldState 绑定
  final FormFieldState<String>? fieldState;

  /// 构建输入格式化器列表
  List<TextInputFormatter> _buildInputFormatters() {
    final formatters = <TextInputFormatter>[];

    if (isDecimal) {
      // 小数输入：允许数字和一个小数点
      if (allowNegative) {
        formatters.add(FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')));
      } else {
        formatters.add(FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')));
      }
      // 使用自定义格式化器限制小数位数
      formatters.add(_DecimalInputFormatter(
        maxDecimalPlaces: maxDecimalPlaces,
        allowNegative: allowNegative,
        maxValue: maxValue,
      ));
    } else {
      // 整数输入：只允许数字（和可选的负号）
      if (allowNegative) {
        formatters.add(FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')));
        formatters.add(_IntegerInputFormatter(
          allowNegative: true,
          maxValue: maxValue?.toInt(),
        ));
      } else {
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        formatters.add(_IntegerInputFormatter(
          allowNegative: false,
          maxValue: maxValue?.toInt(),
        ));
      }
    }

    return formatters;
  }

  @override
  Widget build(BuildContext context) {
    return FormTextField(
      label: label,
      value: value,
      onValueChange: onValueChange,
      placeholder: placeholder,
      icon: icon,
      isRequired: isRequired,
      errorMessage: errorMessage,
      fieldState: fieldState,
      keyboardType: TextInputType.numberWithOptions(
        decimal: isDecimal,
        signed: allowNegative,
      ),
      inputFormatters: _buildInputFormatters(),
      borderType: borderType,
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }
}

/// 整数输入格式化器 - 防止前导零和多个负号
class _IntegerInputFormatter extends TextInputFormatter {
  final bool allowNegative;
  final int? maxValue;

  _IntegerInputFormatter({
    required this.allowNegative,
    this.maxValue,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    String text = newValue.text;

    // 处理负号
    if (allowNegative) {
      // 负号只能在开头，且只能有一个
      if (text.contains('-')) {
        final negCount = '-'.allMatches(text).length;
        if (negCount > 1 || (negCount == 1 && !text.startsWith('-'))) {
          return oldValue;
        }
      }
      // 去掉负号后检查数字部分
      final numPart = text.startsWith('-') ? text.substring(1) : text;
      if (numPart.isNotEmpty) {
        // 防止前导零 (除了单独的 "0")
        if (numPart.length > 1 && numPart.startsWith('0')) {
          return oldValue;
        }
      }
    } else {
      // 防止前导零
      if (text.length > 1 && text.startsWith('0')) {
        return oldValue;
      }
    }

    // 检查最大值
    if (maxValue != null && text.isNotEmpty && text != '-') {
      try {
        final number = int.parse(text);
        if (number > maxValue!) {
          return oldValue;
        }
      } catch (_) {}
    }

    return newValue;
  }
}

/// 小数输入格式化器 - 限制小数位数
class _DecimalInputFormatter extends TextInputFormatter {
  final int maxDecimalPlaces;
  final bool allowNegative;
  final double? maxValue;

  _DecimalInputFormatter({
    required this.maxDecimalPlaces,
    required this.allowNegative,
    this.maxValue,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    String text = newValue.text;

    // 处理负号
    if (text.contains('-')) {
      if (!allowNegative) return oldValue;
      final negCount = '-'.allMatches(text).length;
      if (negCount > 1 || (negCount == 1 && !text.startsWith('-'))) {
        return oldValue;
      }
    }

    // 只允许一个小数点
    final dotCount = '.'.allMatches(text).length;
    if (dotCount > 1) return oldValue;

    // 检查小数位数
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length == 2 && parts[1].length > maxDecimalPlaces) {
        return oldValue;
      }
    }

    // 防止前导零 (除了 "0" 或 "0.xxx")
    final numPart = text.startsWith('-') ? text.substring(1) : text;
    if (numPart.isNotEmpty && !numPart.startsWith('0.') && numPart != '0') {
      if (numPart.length > 1 &&
          numPart.startsWith('0') &&
          !numPart.startsWith('0.')) {
        return oldValue;
      }
    }

    // 检查最大值
    if (maxValue != null && text.isNotEmpty && text != '-' && text != '.') {
      try {
        final number = double.parse(text);
        if (number > maxValue!) {
          return oldValue;
        }
      } catch (_) {}
    }

    return newValue;
  }
}

/// 日期选择框
class FormDatePickerField extends StatelessWidget {
  final String label;
  final int? value; // Milliseconds
  final ValueChanged<int?> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final bool showTime; // 是否显示时间选择 (时分秒)
  final String? title;

  /// 错误信息，支持 String 或 String? Function(BuildContext) 或 String? Function()
  final dynamic errorMessage;
  final FormFieldBorderType borderType;
  final int? labelMaxLines;
  final int maxLines;
  final TextAlign? textAlign;

  /// 创建时回调，暴露 showPicker 方法 (Picker 类型无 controller/focusNode)
  final void Function(TextEditingController? controller, FocusNode? focusNode,
      VoidCallback? showPicker)? onCreate;

  /// 可选的 FormFieldState 绑定，自动绑定 showPicker
  final FormFieldState<int?>? fieldState;

  const FormDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.placeholder = "yyyy/MM/dd",
    this.icon,
    this.isRequired = false,
    this.showTime = false,
    this.title,
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
    this.onCreate,
    this.fieldState,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
  });

  /// 状态绑定构造函数
  FormDatePickerField.state({
    Key? key,
    required FormFieldState<int?> state,
    required this.label,
    this.placeholder = "yyyy/MM/dd",
    this.icon,
    this.isRequired = false,
    this.showTime = false,
    this.title,
    this.borderType = FormFieldBorderType.full,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
  })  : value = state.value,
        onValueChange = state.didChange,
        fieldState = state,
        errorMessage = null,
        onCreate = null,
        super(key: key ?? state.key);

  void _showPicker(BuildContext context) {
    // Hidden keyboard if any
    FocusScope.of(context).unfocus();
    final config = FormFieldConfig.maybeOf(context);

    final initialDate = value != null
        ? DateTime.fromMillisecondsSinceEpoch(value!)
        : DateTime.now();

    if (showTime) {
      // 使用自定义日期时间选择器 (支持时分秒)
      _showDateTimePicker(context, initialDate, config, title);
    } else {
      // 仅选择日期
      _showDateOnlyPicker(context, initialDate, config, title);
    }
  }

  void _showDateOnlyPicker(BuildContext context, DateTime initialDate,
      FormFieldConfig? config, String? title) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        DateTime tempDate = initialDate;
        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text(
                      config?.pickerCancelLabel ?? "取消",
                      style: config?.pickerCancelTextStyle,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      title ?? "请选择$label",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  CupertinoButton(
                    child: Text(
                      config?.pickerConfirmLabel ?? "确定",
                      style: config?.pickerConfirmTextStyle,
                    ),
                    onPressed: () {
                      onValueChange(tempDate.millisecondsSinceEpoch);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  use24hFormat: true,
                  // 使用年-月-日顺序 (中文格式)
                  dateOrder: DatePickerDateOrder.ymd,
                  onDateTimeChanged: (DateTime newDate) {
                    tempDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDateTimePicker(BuildContext context, DateTime initialDate,
      FormFieldConfig? config, String? title) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return _GenericDateTimePicker(
          title: title ?? "请选择$label",
          initialDateTime: initialDate,
          mode: CupertinoDatePickerMode.dateAndTime,
          onConfirm: (dateTime) {
            onValueChange(dateTime.millisecondsSinceEpoch);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = FormFieldConfig.maybeOf(context);

    // 优先级: widget > config > defaults
    final effectiveRowHeight =
        config?.rowHeight ?? FormFieldDefaults.minRowHeight;
    final effectiveHPadding =
        config?.horizontalPadding ?? FormFieldDefaults.horizontalPadding;
    final effectiveVPadding =
        config?.verticalPadding ?? FormFieldDefaults.verticalPadding;
    final effectiveSpacing = config?.spacing ?? FormFieldDefaults.spacing;
    final effectivePickerTextStyle =
        config?.pickerTextStyle ?? theme.textTheme.bodyMedium;
    final effectivePickerPlaceholderStyle = config?.pickerPlaceholderStyle ??
        theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5));

    // 错误信息逻辑
    String? resolvedErrorMessage;
    if (errorMessage is String) {
      resolvedErrorMessage = errorMessage;
    } else if (errorMessage is String? Function(BuildContext)) {
      resolvedErrorMessage =
          (errorMessage as String? Function(BuildContext))(context);
    } else if (errorMessage is String? Function()) {
      resolvedErrorMessage = (errorMessage as String? Function())();
    }

    final effectiveErrorMessage = resolvedErrorMessage ??
        (fieldState?.hasInteracted == true ? fieldState?.errorMessage : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;

    String displayValue = "";
    if (value != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(value!);
      final format = showTime ? "yyyy/MM/dd HH:mm:ss" : "yyyy/MM/dd";
      displayValue = DateFormat(format).format(dt);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            InkWell(
              onTap: () => _showPicker(context),
              child: Container(
                constraints: BoxConstraints(minHeight: effectiveRowHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: effectiveHPadding,
                  vertical: effectiveVPadding,
                ),
                child: Row(
                  children: [
                    FormFieldLabelSection(
                      label: label,
                      icon: icon,
                      isRequired: isRequired,
                      maxLines: labelMaxLines,
                    ),
                    SizedBox(width: effectiveSpacing),
                    Expanded(
                      child: Text(
                        displayValue.isEmpty
                            ? (showTime ? "yyyy/MM/dd HH:mm:ss" : placeholder)
                            : displayValue,
                        style: displayValue.isEmpty
                            ? effectivePickerPlaceholderStyle
                            : effectivePickerTextStyle,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            textAlign ?? config?.textAlign ?? TextAlign.end,
                      ),
                    ),
                    if (value != null) ...[
                      GestureDetector(
                        onTap: () => onValueChange(null),
                        child: Icon(
                          Icons.cancel,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      Icons.date_range,
                      size: FormFieldDefaults.iconSize,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  ],
                ),
              ),
            ),
            FormDivider(
                type: borderType,
                color:
                    hasError ? theme.colorScheme.error.withOpacity(0.5) : null),
          ],
        ),
        // 错误信息使用绝对定位，覆盖在分割线上方，不增加高度
        if (hasError)
          Positioned(
            bottom: 2,
            right: FormFieldDefaults.horizontalPadding,
            child: Text(
              effectiveErrorMessage,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error, fontSize: 10),
            ),
          ),
      ],
    );
  }
}

/// 时间选择框 (时:分)
class FormTimePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final String? title;

  /// 错误信息，支持 String 或 String? Function(BuildContext)
  final dynamic errorMessage;
  final FormFieldBorderType borderType;
  final int? labelMaxLines;
  final int maxLines;
  final TextAlign? textAlign;

  /// 可选的 FormFieldState 绑定
  final FormFieldState<DateTime?>? fieldState;

  FormTimePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.placeholder = "HH:mm",
    this.icon,
    this.isRequired = false,
    this.title,
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
    this.fieldState,
    this.pickerTextStyle,
    this.pickerPlaceholderStyle,
  });

  /// 状态绑定构造函数
  FormTimePickerField.state({
    Key? key,
    required FormFieldState<DateTime?> state,
    required this.label,
    this.placeholder = "HH:mm",
    this.icon,
    this.isRequired = false,
    this.title,
    this.borderType = FormFieldBorderType.full,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
    this.pickerTextStyle,
    this.pickerPlaceholderStyle,
  })  : value = state.value,
        onValueChange = state.didChange,
        fieldState = state,
        errorMessage = null,
        super(key: key ?? state.key);

  // 辅助样式属性
  final TextStyle? pickerTextStyle;
  final TextStyle? pickerPlaceholderStyle;

  void _showTimePicker(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());

    // 获取配置
    final config =
        context.dependOnInheritedWidgetOfExactType<FormFieldConfig>();

    // 计算初始时间 (如果不为空)
    final initialDateTime = value ?? DateTime.now();

    // 动态标题逻辑
    String effectiveTitle = title ?? "选择时间"; // Adjusted for FormTimePickerField

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) {
        return _GenericDateTimePicker(
          title: effectiveTitle,
          initialDateTime: initialDateTime,
          mode: CupertinoDatePickerMode.time,
          onConfirm: (val) {
            onValueChange(val);
            Navigator.pop(ctx);
          },
          config: config,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config =
        context.dependOnInheritedWidgetOfExactType<FormFieldConfig>();

    // 样式合并
    // 样式合并
    final effectivePickerTextStyle = pickerTextStyle ??
        config?.pickerTextStyle ??
        theme.textTheme.bodyMedium;
    final effectivePickerPlaceholderStyle = pickerPlaceholderStyle ??
        config?.pickerPlaceholderStyle ??
        theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5));

    // 显示值逻辑
    String displayValue = "";
    if (value != null) {
      displayValue = DateFormat('HH:mm').format(value!);
    }

    // 错误信息逻辑
    String? resolvedErrorMessage;
    if (errorMessage is String) {
      resolvedErrorMessage = errorMessage;
    } else if (errorMessage is String? Function(BuildContext)) {
      resolvedErrorMessage =
          (errorMessage as String? Function(BuildContext))(context);
    } else if (errorMessage is String? Function()) {
      resolvedErrorMessage = (errorMessage as String? Function())();
    }

    final effectiveErrorMessage = resolvedErrorMessage ??
        (fieldState?.hasInteracted == true ? fieldState?.errorMessage : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            InkWell(
              onTap: () {
                fieldState?.didInteract(); // 标记为已交互
                _showTimePicker(context);
              },
              child: Container(
                constraints: BoxConstraints(
                    minHeight:
                        config?.rowHeight ?? FormFieldDefaults.minRowHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: config?.horizontalPadding ??
                      FormFieldDefaults.horizontalPadding,
                  vertical: config?.verticalPadding ??
                      FormFieldDefaults.verticalPadding,
                ),
                child: Row(
                  children: [
                    FormFieldLabelSection(
                      label: label,
                      icon: icon,
                      isRequired: isRequired,
                      maxLines: labelMaxLines ?? config?.labelMaxLines,
                    ),
                    SizedBox(
                        width: config?.spacing ?? FormFieldDefaults.spacing),
                    Expanded(
                      child: Text(
                        displayValue.isEmpty ? placeholder : displayValue,
                        style: displayValue.isEmpty
                            ? effectivePickerPlaceholderStyle
                            : effectivePickerTextStyle,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            textAlign ?? config?.textAlign ?? TextAlign.end,
                      ),
                    ),
                    if (value != null) ...[
                      GestureDetector(
                        onTap: () => onValueChange(null),
                        child: Icon(
                          Icons.cancel,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      Icons.access_time, // 使用时间图标
                      size: FormFieldDefaults.iconSize,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  ],
                ),
              ),
            ),
            FormDivider(
                type: borderType,
                color:
                    hasError ? theme.colorScheme.error.withOpacity(0.5) : null),
          ],
        ),
        if (hasError)
          Positioned(
            bottom: 2,
            right: FormFieldDefaults.horizontalPadding,
            child: Text(
              effectiveErrorMessage,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error, fontSize: 10),
            ),
          ),
      ],
    );
  }
}

/// 月份选择框 (年月)
class FormMonthPickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final String? title;

  /// 错误信息，支持 String 或 String? Function(BuildContext)
  final dynamic errorMessage;
  final FormFieldBorderType borderType;
  final int? labelMaxLines;
  final int maxLines;
  final TextAlign? textAlign;

  /// 可选的 FormFieldState 绑定
  final FormFieldState<DateTime?>? fieldState;

  // 辅助样式属性
  final TextStyle? pickerTextStyle;
  final TextStyle? pickerPlaceholderStyle;

  FormMonthPickerField({
    Key? key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.placeholder = "yyyy-MM",
    this.icon,
    this.isRequired = false,
    this.title,
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
    this.fieldState,
    this.pickerTextStyle,
    this.pickerPlaceholderStyle,
  }) : super(key: key ?? fieldState?.key);

  /// 状态绑定构造函数
  FormMonthPickerField.state({
    Key? key,
    required FormFieldState<DateTime?> state,
    required this.label,
    this.placeholder = "yyyy-MM",
    this.icon,
    this.isRequired = false,
    this.title,
    this.borderType = FormFieldBorderType.full,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
    this.pickerTextStyle,
    this.pickerPlaceholderStyle,
  })  : value = state.value,
        onValueChange = state.didChange,
        fieldState = state,
        errorMessage = null,
        super(key: key ?? state.key);

  void _showMonthPicker(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());

    // 获取配置
    final config =
        context.dependOnInheritedWidgetOfExactType<FormFieldConfig>();

    // 计算初始日期 (如果不为空)
    final initialDateTime = value ?? DateTime.now();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return _MonthPickerPopup(
          title: title ?? '选择月份',
          initialDate: initialDateTime,
          onConfirm: (val) {
            onValueChange(val);
            Navigator.pop(context);
          },
          config: config,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config =
        context.dependOnInheritedWidgetOfExactType<FormFieldConfig>();

    // 样式合并
    final effectivePickerTextStyle = pickerTextStyle ??
        config?.pickerTextStyle ??
        theme.textTheme.bodyMedium;
    final effectivePickerPlaceholderStyle = pickerPlaceholderStyle ??
        config?.pickerPlaceholderStyle ??
        theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5));

    // 显示值逻辑
    String displayValue = "";
    if (value != null) {
      displayValue = DateFormat('yyyy-MM').format(value!);
    }

    // 错误信息逻辑
    String? resolvedErrorMessage;
    if (errorMessage is String) {
      resolvedErrorMessage = errorMessage;
    } else if (errorMessage is String? Function(BuildContext)) {
      resolvedErrorMessage =
          (errorMessage as String? Function(BuildContext))(context);
    } else if (errorMessage is String? Function()) {
      resolvedErrorMessage = (errorMessage as String? Function())();
    }

    final effectiveErrorMessage = resolvedErrorMessage ??
        (fieldState?.hasInteracted == true ? fieldState?.errorMessage : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            InkWell(
              onTap: () {
                fieldState?.didInteract(); // 标记为已交互
                _showMonthPicker(context);
              },
              child: Container(
                constraints: BoxConstraints(
                    minHeight:
                        config?.rowHeight ?? FormFieldDefaults.minRowHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: config?.horizontalPadding ??
                      FormFieldDefaults.horizontalPadding,
                  vertical: config?.verticalPadding ??
                      FormFieldDefaults.verticalPadding,
                ),
                child: Row(
                  children: [
                    FormFieldLabelSection(
                      label: label,
                      icon: icon,
                      isRequired: isRequired,
                      maxLines: labelMaxLines ?? config?.labelMaxLines,
                    ),
                    SizedBox(
                        width: config?.spacing ?? FormFieldDefaults.spacing),
                    Expanded(
                      child: Text(
                        displayValue.isEmpty ? placeholder : displayValue,
                        style: displayValue.isEmpty
                            ? effectivePickerPlaceholderStyle
                            : effectivePickerTextStyle,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            textAlign ?? config?.textAlign ?? TextAlign.end,
                      ),
                    ),
                    if (value != null) ...[
                      GestureDetector(
                        onTap: () => onValueChange(null),
                        child: Icon(
                          Icons.cancel,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      Icons.calendar_today, // 使用日历图标
                      size: FormFieldDefaults.iconSize,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  ],
                ),
              ),
            ),
            FormDivider(
                type: borderType,
                color:
                    hasError ? theme.colorScheme.error.withOpacity(0.5) : null),
          ],
        ),
        if (hasError)
          Positioned(
            bottom: 2,
            right: FormFieldDefaults.horizontalPadding,
            child: Text(
              effectiveErrorMessage!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error, fontSize: 10),
            ),
          ),
      ],
    );
  }
}

/// 年月选择器弹窗
class _MonthPickerPopup extends StatefulWidget {
  final String title;
  final DateTime initialDate;
  final ValueChanged<DateTime> onConfirm;
  final FormFieldConfig? config;

  const _MonthPickerPopup({
    required this.title,
    required this.initialDate,
    required this.onConfirm,
    this.config,
  });

  @override
  State<_MonthPickerPopup> createState() => _MonthPickerPopupState();
}

class _MonthPickerPopupState extends State<_MonthPickerPopup> {
  late int _selectedYear;
  late int _selectedMonth;
  late List<int> _years;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    // 生成年份范围：前后20年
    final currentYear = DateTime.now().year;
    _years = List.generate(100, (index) => currentYear - 50 + index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = widget.config ?? FormFieldConfig.maybeOf(context);

    return Container(
      height: 300,
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Toolbar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    config?.pickerCancelLabel ?? "取消",
                    style: config?.pickerCancelTextStyle ??
                        theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium,
                ),
                GestureDetector(
                  onTap: () {
                    final date = DateTime(_selectedYear, _selectedMonth);
                    widget.onConfirm(date);
                  },
                  child: Text(
                    config?.pickerConfirmLabel ?? "确定",
                    style: config?.pickerConfirmTextStyle ??
                        theme.textTheme.bodyMedium?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Pickers
          Expanded(
            child: Row(
              children: [
                // Year Picker
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: _years.indexOf(_selectedYear) != -1
                          ? _years.indexOf(_selectedYear)
                          : _years.length ~/ 2,
                    ),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedYear = _years[index];
                      });
                    },
                    selectionOverlay:
                        const CupertinoPickerDefaultSelectionOverlay(),
                    children: _years.map((year) {
                      return Center(child: Text('$year年'));
                    }).toList(),
                  ),
                ),
                // Month Picker
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: _selectedMonth - 1,
                    ),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedMonth = index + 1;
                      });
                    },
                    selectionOverlay:
                        const CupertinoPickerDefaultSelectionOverlay(),
                    children: List.generate(12, (index) {
                      return Center(child: Text('${index + 1}月'));
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 日期范围值 (开始时间和结束时间)
class DateRange {
  final int? startMs; // 开始时间 (毫秒)
  final int? endMs; // 结束时间 (毫秒)

  const DateRange({this.startMs, this.endMs});

  bool get isEmpty => startMs == null && endMs == null;
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() {
    return 'DateRange(start: $startMs, end: $endMs)';
  }
}

/// 日期范围选择器样式
enum DateRangePickerStyle {
  /// 分开选择：点击开始/结束日期分别弹出选择器
  separate,

  /// 合并选择：在一个 sheet 中同时选择开始和结束日期
  combined,
}

/// 日期范围选择框
class FormDateRangePickerField extends StatelessWidget {
  final String label;
  final DateRange value;
  final ValueChanged<DateRange> onValueChange;
  final String startPlaceholder;
  final String endPlaceholder;
  final String separator;
  final IconData? icon;
  final bool isRequired;
  final CupertinoDatePickerMode mode;

  /// 错误信息，支持 String 或 String? Function(BuildContext)
  final dynamic errorMessage;
  final FormFieldBorderType borderType;

  /// 选择器样式
  final DateRangePickerStyle style;
  final String? title;
  final int? labelMaxLines;
  final int maxLines;
  final TextAlign? textAlign;

  FormDateRangePickerField({
    Key? key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.startPlaceholder = "开始日期",
    this.endPlaceholder = "结束日期",
    this.separator = " 至 ",
    this.icon,
    this.isRequired = false,
    this.mode = CupertinoDatePickerMode.date,
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
    this.style = DateRangePickerStyle.separate,
    this.title,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
    this.fieldState,
  }) : super(key: key ?? fieldState?.key);

  /// 状态绑定构造函数
  FormDateRangePickerField.state({
    Key? key,
    required FormFieldState<DateRange> state,
    required this.label,
    this.startPlaceholder = "开始日期",
    this.endPlaceholder = "结束日期",
    this.separator = " 至 ",
    this.icon,
    this.isRequired = false,
    this.mode = CupertinoDatePickerMode.date,
    this.borderType = FormFieldBorderType.full,
    this.style = DateRangePickerStyle.separate,
    this.title,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
  })  : value = state.value,
        onValueChange = state.didChange,
        fieldState = state,
        errorMessage = null,
        super(key: key ?? state.key);

  /// 可选的 FormFieldState 绑定
  final FormFieldState<DateRange>? fieldState;

  /// 分开选择样式
  void _showSeparatePicker(BuildContext context, bool isStart) {
    FocusScope.of(context).unfocus();
    final config = FormFieldConfig.maybeOf(context);

    final currentMs = isStart ? value.startMs : value.endMs;
    // Default to start time if end time is not set, otherwise now
    final initialDate = currentMs != null
        ? DateTime.fromMillisecondsSinceEpoch(currentMs)
        : (!isStart && value.startMs != null
            ? DateTime.fromMillisecondsSinceEpoch(value.startMs!)
            : DateTime.now());

    // 设置最小日期限制
    DateTime? minDate;
    if (isStart && value.endMs != null) {
      // 选择开始日期时，不限制（但修改后会自动调整结束日期）
    } else if (!isStart && value.startMs != null) {
      // 选择结束日期时，最小日期为开始日期
      minDate = DateTime.fromMillisecondsSinceEpoch(value.startMs!);
    }

    // 动态标题逻辑
    String effectiveTitle = title ?? "请选择${isStart ? '开始' : '结束'}$label";

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        DateTime effectiveInitialDate = initialDate;
        if (!isStart &&
            minDate != null &&
            effectiveInitialDate.isBefore(minDate)) {
          effectiveInitialDate = minDate;
        }

        return _GenericDateTimePicker(
          title: effectiveTitle,
          initialDateTime: effectiveInitialDate,
          minimumDate: minDate,
          mode: mode,
          cancelLabel: config?.pickerCancelLabel,
          confirmLabel: config?.pickerConfirmLabel,
          cancelTextStyle: config?.pickerCancelTextStyle,
          confirmTextStyle: config?.pickerConfirmTextStyle,
          onConfirm: (dt) {
            // 如果选择结束日期且小于开始日期，自动调整 (这里简单处理，实际可加提示)
            DateTime finalDate = dt;
            if (!isStart && minDate != null && finalDate.isBefore(minDate)) {
              finalDate = minDate;
            }

            final newMs = finalDate.millisecondsSinceEpoch;
            if (isStart) {
              int? newEndMs = value.endMs;
              if (newEndMs != null && newMs > newEndMs) {
                newEndMs = newMs;
              }
              onValueChange(DateRange(startMs: newMs, endMs: newEndMs));
            } else {
              onValueChange(DateRange(startMs: value.startMs, endMs: newMs));
            }
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  /// 合并选择样式
  void _showCombinedPicker(BuildContext context) {
    FocusScope.of(context).unfocus();
    final config = FormFieldConfig.maybeOf(context);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return _DateRangeCombinedPicker(
          initialRange: value,
          mode: mode,
          title: title ?? "请选择$label",
          cancelLabel: config?.pickerCancelLabel,
          confirmLabel: config?.pickerConfirmLabel,
          cancelTextStyle: config?.pickerCancelTextStyle,
          confirmTextStyle: config?.pickerConfirmTextStyle,
          onConfirm: (range) {
            onValueChange(range);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 错误信息逻辑
    final effectiveErrorMessage = errorMessage ??
        (fieldState?.hasInteracted == true ? fieldState?.errorMessage : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;

    String startDisplay = "";
    String endDisplay = "";
    final format = (mode == CupertinoDatePickerMode.dateAndTime ||
            mode == CupertinoDatePickerMode.time)
        ? "yyyy/MM/dd HH:mm:ss"
        : "yyyy/MM/dd";

    if (value.startMs != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(value.startMs!);
      startDisplay = DateFormat(format).format(date);
    }
    if (value.endMs != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(value.endMs!);
      endDisplay = DateFormat(format).format(date);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            InkWell(
              onTap: style == DateRangePickerStyle.combined
                  ? () => _showCombinedPicker(context)
                  : null,
              child: Container(
                constraints: const BoxConstraints(
                    minHeight: FormFieldDefaults.minRowHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: FormFieldDefaults.horizontalPadding,
                  vertical: FormFieldDefaults.verticalPadding,
                ),
                child: Row(
                  children: [
                    FormFieldLabelSection(
                      label: label,
                      icon: icon,
                      isRequired: isRequired,
                      maxLines: labelMaxLines,
                    ),
                    const SizedBox(width: FormFieldDefaults.spacing),
                    // 开始日期
                    Expanded(
                      child: GestureDetector(
                        onTap: style == DateRangePickerStyle.separate
                            ? () => _showSeparatePicker(context, true)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            startDisplay.isEmpty
                                ? startPlaceholder
                                : startDisplay,
                            style: startDisplay.isEmpty
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.5))
                                : theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                            maxLines: maxLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    // 分隔符
                    Text(
                      separator,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    // 结束日期
                    Expanded(
                      child: GestureDetector(
                        onTap: style == DateRangePickerStyle.separate
                            ? () => _showSeparatePicker(context, false)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            endDisplay.isEmpty ? endPlaceholder : endDisplay,
                            style: endDisplay.isEmpty
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.5))
                                : theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                            maxLines: maxLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    // 清除按钮
                    if (value.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => onValueChange(const DateRange()),
                        child: Icon(
                          Icons.cancel,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      Icons.date_range,
                      size: FormFieldDefaults.iconSize,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            FormDivider(
                type: borderType,
                color:
                    hasError ? theme.colorScheme.error.withOpacity(0.5) : null),
          ],
        ),
        // 错误信息使用绝对定位，覆盖在分割线上方，不增加高度
        if (hasError)
          Positioned(
            bottom: 2,
            right: FormFieldDefaults.horizontalPadding,
            child: Text(
              effectiveErrorMessage!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error, fontSize: 10),
            ),
          ),
      ],
    );
  }
}

/// 合并选择弹窗 (同时选择开始和结束日期)
class _DateRangeCombinedPicker extends StatefulWidget {
  final DateRange initialRange;
  final CupertinoDatePickerMode mode;
  final ValueChanged<DateRange> onConfirm;
  final String title;

  final String? cancelLabel;
  final String? confirmLabel;
  final TextStyle? cancelTextStyle;
  final TextStyle? confirmTextStyle;

  const _DateRangeCombinedPicker({
    required this.initialRange,
    required this.mode,
    required this.onConfirm,
    this.title = "选择日期范围",
    this.cancelLabel,
    this.confirmLabel,
    this.cancelTextStyle,
    this.confirmTextStyle,
  });

  @override
  State<_DateRangeCombinedPicker> createState() =>
      _DateRangeCombinedPickerState();
}

class _DateRangeCombinedPickerState extends State<_DateRangeCombinedPicker> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSelectingStart = true; // true: 选择开始日期, false: 选择结束日期

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = widget.initialRange.startMs != null
        ? DateTime.fromMillisecondsSinceEpoch(widget.initialRange.startMs!)
        : now;
    _endDate = widget.initialRange.endMs != null
        ? DateTime.fromMillisecondsSinceEpoch(widget.initialRange.endMs!)
        : (widget.initialRange.startMs != null
            ? DateTime.fromMillisecondsSinceEpoch(widget.initialRange.startMs!)
            : now);
    // 确保结束日期不早于开始日期
    if (_endDate.isBefore(_startDate)) {
      _endDate = _startDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = (widget.mode == CupertinoDatePickerMode.dateAndTime ||
            widget.mode == CupertinoDatePickerMode.time)
        ? "yyyy/MM/dd HH:mm:ss"
        : "yyyy/MM/dd";

    return Container(
      height: 380,
      color: Colors.white,
      child: Column(
        children: [
          // 头部
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                child: Text(
                  widget.cancelLabel ?? "取消",
                  style: widget.cancelTextStyle,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              Material(
                color: Colors.transparent,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              CupertinoButton(
                child: Text(
                  widget.confirmLabel ?? "确定",
                  style: widget.confirmTextStyle,
                ),
                onPressed: () {
                  widget.onConfirm(DateRange(
                    startMs: _startDate.millisecondsSinceEpoch,
                    endMs: _endDate.millisecondsSinceEpoch,
                  ));
                },
              ),
            ],
          ),
          // 切换按钮
          Material(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSelectingStart = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isSelectingStart
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "开始日期",
                              style: TextStyle(
                                fontSize: 12,
                                color: _isSelectingStart
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(format).format(_startDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isSelectingStart
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSelectingStart = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isSelectingStart
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "结束日期",
                              style: TextStyle(
                                fontSize: 12,
                                color: !_isSelectingStart
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(format).format(_endDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !_isSelectingStart
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 日期选择器
          Expanded(
            child: _GenericDatePickerWheel(
              mode: widget.mode,
              initialDateTime: _isSelectingStart ? _startDate : _endDate,
              minimumDate: _isSelectingStart ? null : _startDate,
              onDateTimeChanged: (DateTime newDate) {
                setState(() {
                  if (_isSelectingStart) {
                    _startDate = newDate;
                    if (_endDate.isBefore(_startDate)) {
                      _endDate = _startDate;
                    }
                  } else {
                    _endDate = newDate;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GenericDatePickerWheel extends StatefulWidget {
  final DateTime initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;
  final CupertinoDatePickerMode mode;
  final DateTime? minimumDate;

  const _GenericDatePickerWheel({
    required this.initialDateTime,
    required this.onDateTimeChanged,
    this.mode = CupertinoDatePickerMode.date,
    this.minimumDate,
  });

  @override
  State<_GenericDatePickerWheel> createState() =>
      _GenericDatePickerWheelState();
}

class _GenericDatePickerWheelState extends State<_GenericDatePickerWheel> {
  late int _year;
  late int _month;
  late int _day;
  late int _hour;
  late int _minute;
  late int _second;

  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _secondCtrl;

  final int _minYear = DateTime.now().year - 50;
  final int _maxYear = DateTime.now().year + 50;
  late List<int> _years;

  @override
  void initState() {
    super.initState();
    _years = List.generate(_maxYear - _minYear + 1, (i) => _minYear + i);
    _syncFromWidget(false);
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant _GenericDatePickerWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDateTime != widget.initialDateTime ||
        oldWidget.minimumDate != widget.minimumDate) {
      // Added minimumDate check
      // Check if we need to animate to the new date
      // We only animate if the internal state differs from the new widget state
      // (which means the parent corrected the value)
      final internalDate =
          DateTime(_year, _month, _day, _hour, _minute, _second);
      if (internalDate != widget.initialDateTime) {
        _syncFromWidget(true);
      }
    }
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
  }

  void _initControllers() {
    _yearCtrl = FixedExtentScrollController(initialItem: _years.indexOf(_year));
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _secondCtrl = FixedExtentScrollController(initialItem: _second);
  }

  void _syncFromWidget(bool animate) {
    _year = widget.initialDateTime.year;
    _month = widget.initialDateTime.month;
    _day = widget.initialDateTime.day;
    _hour = widget.initialDateTime.hour;
    _minute = widget.initialDateTime.minute;
    _second = widget.initialDateTime.second;

    if (animate) {
      // Animate controllers to new positions
      if (_yearCtrl.hasClients) {
        final yearIndex = _years.indexOf(_year);
        if (yearIndex != -1 && yearIndex != _yearCtrl.selectedItem) {
          _yearCtrl.animateToItem(yearIndex,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      }
      if (_monthCtrl.hasClients && (_month - 1) != _monthCtrl.selectedItem) {
        _monthCtrl.animateToItem(_month - 1,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      if (_dayCtrl.hasClients) {
        // Need to ensure day is valid before animating?
        // _fixDay is called on change, but here we are setting explicit value.
        // Also max days might change if month changed.
        // Ideally we should wait for month animation?
        // For simplicity, just animate to target day index.
        // Note: day list length depends on month/year.
        if ((_day - 1) != _dayCtrl.selectedItem) {
          _dayCtrl.animateToItem(_day - 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      }
      if (_hourCtrl.hasClients && _hour != _hourCtrl.selectedItem) {
        _hourCtrl.animateToItem(_hour,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      if (_minuteCtrl.hasClients && _minute != _minuteCtrl.selectedItem) {
        _minuteCtrl.animateToItem(_minute,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      if (_secondCtrl.hasClients && _second != _secondCtrl.selectedItem) {
        _secondCtrl.animateToItem(_second,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    }
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _fixDay() {
    final maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
      // If day was clamped, we might need to jump/animate day controller?
      // But _fixDay is usually called BEFORE _notifyChange or updating UI
    }
  }

  bool _isScrolling = false;

  void _notifyChange() {
    DateTime dt = DateTime(_year, _month, _day, _hour, _minute, _second);

    if (widget.minimumDate != null) {
      if (dt.isBefore(widget.minimumDate!)) {
        // Enforce minimumDate with smart clamp
        // Instead of hard reset to minimumDate, we clamp components hierarchically
        // to preserve user selection in lower-order fields if possible.
        final min = widget.minimumDate!;
        var y = _year;
        var m = _month;
        var d = _day;
        var h = _hour;
        var min_ = _minute;
        var s = _second;

        // Year
        if (y < min.year) y = min.year;

        // Month
        if (y == min.year) {
          if (m < min.month) m = min.month;
        }

        // Day
        // First ensure day is valid for the (potentially new) month
        final maxDay = _daysInMonth(y, m);
        if (d > maxDay) d = maxDay;

        if (y == min.year && m == min.month) {
          if (d < min.day) d = min.day;
        }

        // Hour
        if (y == min.year && m == min.month && d == min.day) {
          if (h < min.hour) h = min.hour;
        }

        // Minute
        if (y == min.year && m == min.month && d == min.day && h == min.hour) {
          if (min_ < min.minute) min_ = min.minute;
        }

        // Second
        if (y == min.year &&
            m == min.month &&
            d == min.day &&
            h == min.hour &&
            min_ == min.minute) {
          if (s < min.second) s = min.second;
        }

        dt = DateTime(y, m, d, h, min_, s);

        // Only snap visually if NOT scrolling
        if (!_isScrolling) {
          // Sync internal state and animate
          setState(() {
            _year = dt.year;
            _month = dt.month;
            _day = dt.day;
            _hour = dt.hour;
            _minute = dt.minute;
            _second = dt.second;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncFromWidget(true);
          });
        }
      }
    }

    widget.onDateTimeChanged(dt);
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) => i + 1);
    final days = List.generate(_daysInMonth(_year, _month), (i) => i + 1);
    final hours = List.generate(24, (i) => i);
    final minutes = List.generate(60, (i) => i);
    final seconds = List.generate(60, (i) => i);

    final showDate = widget.mode == CupertinoDatePickerMode.date ||
        widget.mode == CupertinoDatePickerMode.dateAndTime;
    final showTime = widget.mode == CupertinoDatePickerMode.time ||
        widget.mode == CupertinoDatePickerMode.dateAndTime;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _isScrolling = true;
        } else if (notification is ScrollEndNotification) {
          _isScrolling = false;
          // Trigger a final check/snap when scrolling ends
          _notifyChange();
        }
        return false;
      },
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Row(
            children: [
              if (showDate) ...[
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    selectionOverlay: const SizedBox(),
                    scrollController: _yearCtrl,
                    onSelectedItemChanged: (idx) {
                      setState(() {
                        _year = _years[idx];
                        _fixDay();
                      });
                      _notifyChange();
                    },
                    children: _years
                        .map((e) => Center(
                            child: Text("$e年",
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    key: ValueKey(
                        _year), // Keep key to force refresh days if year changes affecting leap year
                    itemExtent: 36,
                    selectionOverlay: const SizedBox(),
                    scrollController: _monthCtrl,
                    onSelectedItemChanged: (idx) {
                      setState(() {
                        _month = months[idx];
                        _fixDay();
                      });
                      _notifyChange();
                    },
                    children: months
                        .map((e) => Center(
                            child: Text("$e月",
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    key: ValueKey("$_year-$_month"),
                    itemExtent: 36,
                    selectionOverlay: const SizedBox(),
                    scrollController: _dayCtrl,
                    onSelectedItemChanged: (idx) {
                      setState(() {
                        _day = days[idx];
                      });
                      _notifyChange();
                    },
                    children: days
                        .map((e) => Center(
                            child: Text("$e日",
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                  ),
                ),
              ],
              if (showTime) ...[
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    selectionOverlay: const SizedBox(),
                    scrollController: _hourCtrl,
                    onSelectedItemChanged: (idx) {
                      setState(() {
                        _hour = hours[idx];
                      });
                      _notifyChange();
                    },
                    children: hours
                        .map((e) => Center(
                            child: Text("${e.toString().padLeft(2, '0')}时",
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    selectionOverlay: const SizedBox(),
                    scrollController: _minuteCtrl,
                    onSelectedItemChanged: (idx) {
                      setState(() {
                        _minute = minutes[idx];
                      });
                      _notifyChange();
                    },
                    children: minutes
                        .map((e) => Center(
                            child: Text("${e.toString().padLeft(2, '0')}分",
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    selectionOverlay: const SizedBox(),
                    scrollController: _secondCtrl,
                    onSelectedItemChanged: (idx) {
                      setState(() {
                        _second = seconds[idx];
                      });
                      _notifyChange();
                    },
                    children: seconds
                        .map((e) => Center(
                            child: Text("${e.toString().padLeft(2, '0')}秒",
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GenericDateTimePicker extends StatefulWidget {
  final DateTime initialDateTime;
  final ValueChanged<DateTime> onConfirm;
  final String title;
  final String? cancelLabel;
  final String? confirmLabel;
  final TextStyle? cancelTextStyle;
  final TextStyle? confirmTextStyle;
  final CupertinoDatePickerMode mode;
  final DateTime? minimumDate;
  final FormFieldConfig? config;

  const _GenericDateTimePicker({
    required this.initialDateTime,
    required this.onConfirm,
    this.title = "选择日期时间",
    this.cancelLabel,
    this.confirmLabel,
    this.cancelTextStyle,
    this.confirmTextStyle,
    this.mode = CupertinoDatePickerMode.date,
    this.minimumDate,
    this.config,
  });

  @override
  State<_GenericDateTimePicker> createState() => _GenericDateTimePickerState();
}

class _GenericDateTimePickerState extends State<_GenericDateTimePicker> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDateTime;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      color: Colors.white,
      child: Column(
        children: [
          // 顶部按钮
          Row(
            children: [
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  widget.cancelLabel ?? "取消",
                  style: widget.cancelTextStyle,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Material(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  widget.confirmLabel ?? "确定",
                  style: widget.confirmTextStyle,
                ),
                onPressed: () {
                  widget.onConfirm(_currentDate);
                },
              ),
            ],
          ),
          // Picker 区域
          Expanded(
            child: _GenericDatePickerWheel(
              initialDateTime: _currentDate,
              minimumDate: widget.minimumDate,
              mode: widget.mode,
              onDateTimeChanged: (val) {
                _currentDate = val;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用选择器
class FormPickerField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final String? title;

  /// 错误信息，支持 String 或 String? Function(BuildContext)
  final dynamic errorMessage;
  final FormFieldBorderType borderType;
  final int? labelMaxLines;
  final int maxLines;
  final TextAlign? textAlign;

  const FormPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onValueChange,
    this.placeholder = "请选择",
    this.icon,
    this.isRequired = false,
    this.title,
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
    this.fieldState,
  });

  /// 状态绑定构造函数
  FormPickerField.state({
    Key? key,
    required FormFieldState<String> state,
    required this.label,
    required this.options,
    this.placeholder = "请选择",
    this.icon,
    this.isRequired = false,
    this.title,
    this.borderType = FormFieldBorderType.full,
    this.labelMaxLines,
    this.maxLines = 1,
    this.textAlign,
  })  : value = state.value,
        onValueChange = state.didChange,
        fieldState = state,
        errorMessage = null,
        super(key: key ?? state.key);

  /// 可选的 FormFieldState 绑定 (用于自动错误信息)
  final FormFieldState<String>? fieldState;

  void _showPicker(BuildContext context) {
    FocusScope.of(context).unfocus();
    final config = FormFieldConfig.maybeOf(context);

    // Initial index
    int initialIndex = options.indexOf(value);
    if (initialIndex < 0) initialIndex = 0;

    // Temporary value to support "Confirm" action
    // But standard Cupertino picker updates realtime usually.
    // Let's implement realtime update for simplicity, or we can use stateful widget wrapper for "Confirm" logic.
    // For simplicity and standard iOS behavior, realtime update is often used, but here the Android version had Confirm.
    // Let's stick to simple realtime update or a local var.

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        String tempValue = options.isNotEmpty ? options[initialIndex] : "";

        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text(
                      config?.pickerCancelLabel ?? "取消",
                      style: config?.pickerCancelTextStyle,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Text(title ?? "请选择$label",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  CupertinoButton(
                    child: Text(
                      config?.pickerConfirmLabel ?? "确定",
                      style: config?.pickerConfirmTextStyle,
                    ),
                    onPressed: () {
                      onValueChange(tempValue);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 44,
                  scrollController:
                      FixedExtentScrollController(initialItem: initialIndex),
                  onSelectedItemChanged: (index) {
                    if (index >= 0 && index < options.length) {
                      tempValue = options[index];
                    }
                  },
                  children: options.map((e) => Center(child: Text(e))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = FormFieldConfig.maybeOf(context);

    // 错误信息逻辑
    final effectiveErrorMessage = errorMessage ??
        (fieldState?.hasInteracted == true ? fieldState?.errorMessage : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: () => _showPicker(context),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: FormFieldDefaults.minRowHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: FormFieldDefaults.horizontalPadding,
              vertical: FormFieldDefaults.verticalPadding,
            ),
            child: Row(
              children: [
                FormFieldLabelSection(
                  label: label,
                  icon: icon,
                  isRequired: isRequired,
                  maxLines: labelMaxLines,
                ),
                const SizedBox(width: FormFieldDefaults.spacing),
                Expanded(
                  child: Text(
                    value.isEmpty ? placeholder : value,
                    style: value.isEmpty
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5))
                        : theme.textTheme.bodyMedium,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: textAlign ?? config?.textAlign ?? TextAlign.end,
                  ),
                ),
                if (value.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => onValueChange(""),
                    child: Icon(
                      Icons.cancel,
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right,
                  size: FormFieldDefaults.iconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        FormDivider(type: borderType),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(
                left: FormFieldDefaults.horizontalPadding, top: 4),
            child: Text(
              effectiveErrorMessage!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }
}

// ==========================================
// Cascade Picker Support
// ==========================================

class CascadeItem {
  final String value;
  final List<CascadeItem> children;

  const CascadeItem(this.value, [this.children = const []]);
}

class CascadeOptions {
  final List<CascadeItem> level1;
  const CascadeOptions(this.level1);

  static CascadeOptions fromMap(Map<String, dynamic> map) {
    return CascadeOptions(
        map.entries.map((e) => _parseMapItem(e.key, e.value)).toList());
  }

  static CascadeItem _parseMapItem(String key, dynamic value) {
    List<CascadeItem> children = [];
    if (value is List) {
      children = value.map((e) => CascadeItem(e.toString())).toList();
    } else if (value is Map) {
      children = value.entries
          .map((e) => _parseMapItem(e.key.toString(), e.value))
          .toList();
    }
    return CascadeItem(key, children);
  }
}

/// 多级联动选择器
class FormCascadePickerField extends StatelessWidget {
  final String label;
  final List<String> value;
  final CascadeOptions options;
  final ValueChanged<List<String>> onValueChange;
  final String placeholder;
  final IconData? icon;
  final String? title;
  final FormFieldBorderType borderType;
  final String separator;
  final bool isRequired;

  /// 错误信息，支持 String 或 String? Function(BuildContext)
  final dynamic errorMessage;

  /// 文本显示模式：wrap(换行), ellipsisEnd(结尾省略), ellipsisStart(头部省略)
  final FormTextDisplayMode textDisplayMode;

  /// 换行时的最大行数 (仅 wrap 模式有效)
  final int maxLines;
  final int? labelMaxLines;
  final TextAlign? textAlign;

  const FormCascadePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onValueChange,
    this.placeholder = "请选择",
    this.icon,
    this.title,
    this.borderType = FormFieldBorderType.full,
    this.separator = " ",
    this.isRequired = false,
    this.textDisplayMode = FormTextDisplayMode.ellipsisEnd,
    this.maxLines = 2,
    this.errorMessage,
    this.labelMaxLines,
    this.textAlign,
    this.fieldState,
  });

  /// 状态绑定构造函数
  FormCascadePickerField.state({
    Key? key,
    required FormFieldState<List<String>> state,
    required this.label,
    required this.options,
    this.placeholder = "请选择",
    this.icon,
    this.title,
    this.borderType = FormFieldBorderType.full,
    this.separator = " ",
    this.isRequired = false,
    this.textDisplayMode = FormTextDisplayMode.ellipsisEnd,
    this.maxLines = 2,
    this.labelMaxLines,
    this.textAlign,
  })  : value = state.value,
        onValueChange = state.didChange,
        fieldState = state,
        errorMessage = null,
        super(key: key ?? state.key);

  /// 可选的 FormFieldState 绑定
  final FormFieldState<List<String>>? fieldState;

  void _showPicker(BuildContext context) {
    FocusScope.of(context).unfocus();
    final config = FormFieldConfig.maybeOf(context);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return _CascadePickerPopup(
          title: title ?? "请选择$label",
          options: options,
          initialValue: value,
          cancelLabel: config?.pickerCancelLabel,
          confirmLabel: config?.pickerConfirmLabel,
          cancelTextStyle: config?.pickerCancelTextStyle,
          confirmTextStyle: config?.pickerConfirmTextStyle,
          onConfirm: (val) {
            onValueChange(val);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  /// 构建左边省略的文本 (... + 尾部字符)
  /// 使用 TextPainter 测量宽度，计算能显示多少尾部字符
  Widget _buildEllipsisStartText(
    String text,
    TextStyle? style,
    double maxWidth,
    int maxLines,
  ) {
    const ellipsis = '...';

    // 1. Check if full text fits
    final fullPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    if (!fullPainter.didExceedMaxLines) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        textAlign: textAlign ?? TextAlign.end,
      );
    }

    // 2. Binary search for longest suffix
    int low = 0;
    int high = text.length;
    int bestLen = 0;

    while (low <= high) {
      int mid = (low + high) ~/ 2;
      if (mid == 0) {
        low = mid + 1;
        continue;
      }
      String suffix = text.substring(text.length - mid);
      final painter = TextPainter(
        text: TextSpan(text: ellipsis + suffix, style: style),
        maxLines: maxLines,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      if (!painter.didExceedMaxLines) {
        bestLen = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return Text(
      ellipsis + text.substring(text.length - bestLen),
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.clip,
      textAlign: textAlign ?? TextAlign.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = FormFieldConfig.maybeOf(context);

    final effectiveRowHeight =
        config?.rowHeight ?? FormFieldDefaults.minRowHeight;
    final effectiveHPadding =
        config?.horizontalPadding ?? FormFieldDefaults.horizontalPadding;
    final effectiveVPadding =
        config?.verticalPadding ?? FormFieldDefaults.verticalPadding;
    final effectiveSpacing = config?.spacing ?? FormFieldDefaults.spacing;
    final effectivePickerTextStyle =
        config?.pickerTextStyle ?? theme.textTheme.bodyMedium;
    final effectivePickerPlaceholderStyle = config?.pickerPlaceholderStyle ??
        theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5));

    // 错误信息逻辑
    String? resolvedErrorMessage;
    if (errorMessage is String) {
      resolvedErrorMessage = errorMessage;
    } else if (errorMessage is String? Function(BuildContext)) {
      resolvedErrorMessage =
          (errorMessage as String? Function(BuildContext))(context);
    } else if (errorMessage is String? Function()) {
      resolvedErrorMessage = (errorMessage as String? Function())();
    }

    final effectiveErrorMessage = resolvedErrorMessage ??
        (fieldState?.hasInteracted == true ? fieldState?.errorMessage : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;

    final displayValue = value.join(separator);

    // 根据显示模式设置 overflow 和 maxLines
    TextOverflow overflow;
    int? effectiveMaxLines;
    switch (textDisplayMode) {
      case FormTextDisplayMode.wrap:
        overflow = TextOverflow.ellipsis;
        effectiveMaxLines = maxLines;
        break;
      case FormTextDisplayMode.ellipsisEnd:
        overflow = TextOverflow.ellipsis;
        effectiveMaxLines = maxLines;
        break;
      case FormTextDisplayMode.ellipsisStart:
        // Flutter 不直接支持 ellipsisStart，使用 fade + 反转文字方向
        overflow = TextOverflow.fade;
        effectiveMaxLines = maxLines;
        break;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _showPicker(context),
              child: Container(
                constraints: BoxConstraints(minHeight: effectiveRowHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: effectiveHPadding,
                  vertical: effectiveVPadding,
                ),
                child: Row(
                  children: [
                    FormFieldLabelSection(
                        label: label, icon: icon, isRequired: isRequired),
                    SizedBox(width: effectiveSpacing),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 头部省略需要测量文字来计算显示内容
                          if (textDisplayMode ==
                                  FormTextDisplayMode.ellipsisStart &&
                              displayValue.isNotEmpty) {
                            return _buildEllipsisStartText(
                              displayValue,
                              effectivePickerTextStyle,
                              constraints.maxWidth,
                              effectiveMaxLines!,
                            );
                          }

                          // 其他模式直接用 Text
                          return Text(
                            displayValue.isEmpty ? placeholder : displayValue,
                            style: displayValue.isEmpty
                                ? effectivePickerPlaceholderStyle
                                : effectivePickerTextStyle,
                            maxLines: effectiveMaxLines,
                            overflow: overflow,
                            textAlign:
                                textAlign ?? config?.textAlign ?? TextAlign.end,
                          );
                        },
                      ),
                    ),
                    if (value.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => onValueChange([]),
                        child: Icon(
                          Icons.cancel,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      Icons.chevron_right,
                      size: FormFieldDefaults.iconSize,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            FormDivider(
              type: borderType,
              color: hasError ? theme.colorScheme.error.withOpacity(0.5) : null,
            ),
          ],
        ),
        // 错误信息
        if (hasError)
          Positioned(
            bottom: 2,
            right: effectiveHPadding,
            child: Text(
              effectiveErrorMessage!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }
}

class _CascadePickerPopup extends StatefulWidget {
  final String title;
  final CascadeOptions options;
  final List<String> initialValue;
  final ValueChanged<List<String>> onConfirm;

  final String? cancelLabel;
  final String? confirmLabel;
  final TextStyle? cancelTextStyle;
  final TextStyle? confirmTextStyle;

  const _CascadePickerPopup({
    required this.title,
    required this.options,
    required this.initialValue,
    required this.onConfirm,
    this.cancelLabel,
    this.confirmLabel,
    this.cancelTextStyle,
    this.confirmTextStyle,
  });

  @override
  State<_CascadePickerPopup> createState() => _CascadePickerPopupState();
}

class _CascadePickerPopupState extends State<_CascadePickerPopup> {
  late String _l1;
  late String _l2;
  late String _l3;

  // Levels count
  int get _levels {
    // Simple heuristic: check max depth
    bool hasL2 = widget.options.level1.any((e) => e.children.isNotEmpty);
    bool hasL3 = widget.options.level1
        .any((e) => e.children.any((c) => c.children.isNotEmpty));
    if (hasL3) return 3;
    if (hasL2) return 2;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    // Initialize state
    _l1 = "";
    _l2 = "";
    _l3 = "";

    if (widget.initialValue.isNotEmpty) _l1 = widget.initialValue[0];
    if (widget.initialValue.length > 1) _l2 = widget.initialValue[1];
    if (widget.initialValue.length > 2) _l3 = widget.initialValue[2];

    _fixConsistency();
  }

  void _fixConsistency() {
    // Ensure l1 is valid
    if (_l1.isEmpty && widget.options.level1.isNotEmpty) {
      _l1 = widget.options.level1.first.value;
    } else if (widget.options.level1.every((e) => e.value != _l1) &&
        widget.options.level1.isNotEmpty) {
      _l1 = widget.options.level1.first.value;
    }

    // Ensure l2 is valid
    final l1Node = widget.options.level1.firstWhere((e) => e.value == _l1,
        orElse: () => widget.options.level1.first);
    final l2Options = l1Node.children;

    if (l2Options.isNotEmpty) {
      if (_l2.isEmpty || l2Options.every((e) => e.value != _l2)) {
        _l2 = l2Options.first.value;
      }
    } else {
      _l2 = "";
    }

    // Ensure l3 is valid
    final l2Node = l2Options.firstWhere((e) => e.value == _l2,
        orElse: () => CascadeItem(""));
    final l3Options = l2Node.children;

    if (l3Options.isNotEmpty) {
      if (_l3.isEmpty || l3Options.every((e) => e.value != _l3)) {
        _l3 = l3Options.first.value;
      }
    } else {
      _l3 = "";
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取配置
    final config = FormFieldConfig.maybeOf(context);

    int levels = _levels;

    // Data preparation
    final l1Node = widget.options.level1.firstWhere((e) => e.value == _l1,
        orElse: () => widget.options.level1.first);
    final l2Options = l1Node.children;
    final l2Node = l2Options.firstWhere((e) => e.value == _l2,
        orElse: () => CascadeItem(""));
    final l3Options = l2Node.children;

    // Indices
    int i1 = widget.options.level1.indexWhere((e) => e.value == _l1);
    if (i1 < 0) i1 = 0;
    int i2 = l2Options.indexWhere((e) => e.value == _l2);
    if (i2 < 0) i2 = 0;
    int i3 = l3Options.indexWhere((e) => e.value == _l3);
    if (i3 < 0) i3 = 0;

    return Container(
      height: 300,
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                child: Text(
                  config?.pickerCancelLabel ?? "取消",
                  style: config?.pickerCancelTextStyle,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              Material(
                color: Colors.transparent,
                child: Text(widget.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              CupertinoButton(
                child: Text(
                  config?.pickerConfirmLabel ?? "确定",
                  style: config?.pickerConfirmTextStyle,
                ),
                onPressed: () {
                  List<String> result = [];
                  if (levels >= 1) result.add(_l1);
                  if (levels >= 2) result.add(_l2);
                  if (levels >= 3) result.add(_l3);
                  widget.onConfirm(result);
                },
              ),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                // Shared Background Overlay
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 44, // Matches itemExtent
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                // Pickers Row
                Row(
                  children: [
                    // Level 1
                    Expanded(
                      child: CupertinoPicker(
                        selectionOverlay:
                            const SizedBox(), // Transparent overlay
                        itemExtent: 44,
                        scrollController:
                            FixedExtentScrollController(initialItem: i1),
                        onSelectedItemChanged: (idx) {
                          setState(() {
                            if (idx >= 0 &&
                                idx < widget.options.level1.length) {
                              _l1 = widget.options.level1[idx].value;
                              _fixConsistency();
                            }
                          });
                        },
                        children: widget.options.level1
                            .map((e) => Center(
                                child: Text(e.value,
                                    style: const TextStyle(fontSize: 16))))
                            .toList(),
                      ),
                    ),

                    // Level 2
                    if (levels >= 2)
                      Expanded(
                        child: CupertinoPicker(
                          key: ValueKey(
                              _l1), // Keep state fresh when parent changes
                          selectionOverlay:
                              const SizedBox(), // Transparent overlay
                          itemExtent: 44,
                          scrollController:
                              FixedExtentScrollController(initialItem: i2),
                          onSelectedItemChanged: (idx) {
                            setState(() {
                              if (idx >= 0 && idx < l2Options.length) {
                                _l2 = l2Options[idx].value;
                                _fixConsistency();
                              }
                            });
                          },
                          children: l2Options
                              .map((e) => Center(
                                  child: Text(e.value,
                                      style: const TextStyle(fontSize: 16))))
                              .toList(),
                        ),
                      ),

                    // Level 3
                    if (levels >= 3)
                      Expanded(
                        child: CupertinoPicker(
                          key: ValueKey(
                              "$_l1-$_l2"), // Keep state fresh when parent changes
                          selectionOverlay:
                              const SizedBox(), // Transparent overlay
                          itemExtent: 44,
                          scrollController:
                              FixedExtentScrollController(initialItem: i3),
                          onSelectedItemChanged: (idx) {
                            setState(() {
                              if (idx >= 0 && idx < l3Options.length) {
                                _l3 = l3Options[idx].value;
                              }
                            });
                          },
                          children: l3Options
                              .map((e) => Center(
                                  child: Text(e.value,
                                      style: const TextStyle(fontSize: 16))))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Flutter Hooks 版本的组件
// =============================================================================

/// 使用 flutter_hooks 的文本输入框
/// 自动管理 TextEditingController 和 FocusNode 的生命周期，无需手动 dispose
class HookFormTextField extends HookWidget {
  final String label;
  final String value;
  final ValueChanged<String> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final int? maxLength;
  final bool showCharCount;
  final bool enabled;
  final String? errorMessage;
  final int maxLines;
  final int minLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final FormFieldBorderType borderType;
  final FormClearButtonMode clearButtonMode;
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final double? rowHeight;

  const HookFormTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.placeholder = "",
    this.icon,
    this.isRequired = false,
    this.maxLength,
    this.showCharCount = true,
    this.enabled = true,
    this.errorMessage,
    this.maxLines = 1,
    this.minLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.borderType = FormFieldBorderType.full,
    this.clearButtonMode = FormClearButtonMode.always,
    this.labelStyle,
    this.textStyle,
    this.placeholderStyle,
    this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveRowHeight = rowHeight ?? FormFieldDefaults.minRowHeight;

    // 使用 hooks 自动管理 controller 和 focusNode 的生命周期
    final controller = useTextEditingController(text: value);
    final focusNode = useFocusNode();
    final isFocused = useState(false);

    // 监听焦点变化
    useEffect(() {
      void onFocusChange() {
        isFocused.value = focusNode.hasFocus;
      }

      focusNode.addListener(onFocusChange);
      return () => focusNode.removeListener(onFocusChange);
    }, [focusNode]);

    // 同步外部 value 到 controller
    useEffect(() {
      if (controller.text != value) {
        final selection = controller.selection;
        controller.text = value;
        if (selection.baseOffset >= 0 && selection.baseOffset <= value.length) {
          controller.selection = selection;
        }
      }
      return null;
    }, [value]);

    // 显示清除按钮逻辑
    bool showClear = false;
    if (value.isNotEmpty) {
      switch (clearButtonMode) {
        case FormClearButtonMode.never:
          showClear = false;
          break;
        case FormClearButtonMode.whileEditing:
          showClear = isFocused.value;
          break;
        case FormClearButtonMode.always:
          showClear = true;
          break;
      }
    }

    return Column(
      children: [
        Container(
          constraints: BoxConstraints(minHeight: effectiveRowHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: FormFieldDefaults.horizontalPadding,
            vertical: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Label
              FormFieldLabelSection(
                label: label,
                icon: icon,
                isRequired: isRequired,
                labelStyle: labelStyle,
              ),
              const SizedBox(width: FormFieldDefaults.spacing),

              // Input
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: minLines,
                  obscureText: obscureText,
                  maxLength: maxLength,
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  style: textStyle ?? theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: placeholderStyle ??
                        theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: onValueChange,
                ),
              ),

              // Clear Button
              if (showClear && enabled) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    onValueChange("");
                    controller.clear();
                  },
                  child: Icon(
                    Icons.cancel,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    size: 20,
                  ),
                ),
              ],

              // Custom Char Count
              if (maxLength != null && showCharCount && value.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  "${value.length}/$maxLength",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: value.length >= maxLength!
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        // 错误信息显示在分割线上方，贴着分割线
        if (errorMessage != null && errorMessage!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              right: FormFieldDefaults.horizontalPadding,
              bottom: 2,
            ),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
              ),
            ),
          ),
        FormDivider(
          type: borderType,
          color: (errorMessage != null && errorMessage!.isNotEmpty)
              ? theme.colorScheme.error.withOpacity(0.5)
              : null,
        ),
      ],
    );
  }
}

/// 使用 flutter_hooks 的数字输入框
/// 内部使用 HookFormTextField
class HookFormNumberField extends HookWidget {
  final String label;
  final String value;
  final ValueChanged<String> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final bool isDecimal;
  final int maxDecimalPlaces;
  final double? maxValue;
  final bool allowNegative;
  final String? errorMessage;
  final FormFieldBorderType borderType;

  const HookFormNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.placeholder = "请输入数字",
    this.icon,
    this.isRequired = false,
    this.isDecimal = false,
    this.maxDecimalPlaces = 2,
    this.maxValue,
    this.allowNegative = false,
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
  });

  void _handleValueChange(String input) {
    if (input.isEmpty) {
      onValueChange("");
      return;
    }

    if (input == "-" && allowNegative) {
      onValueChange(input);
      return;
    }

    final integerPart = allowNegative ? r"-?(0|[1-9]\d*)" : r"(0|[1-9]\d*)";
    final decimalPart = isDecimal ? "(\\.\\d{0,$maxDecimalPlaces})?" : "";
    final regex = RegExp("^$integerPart$decimalPart\$");

    if (!regex.hasMatch(input)) return;

    if (maxValue != null) {
      final val = double.tryParse(input);
      if (val != null && val > maxValue!) return;
    }

    onValueChange(input);
  }

  @override
  Widget build(BuildContext context) {
    return HookFormTextField(
      label: label,
      value: value,
      onValueChange: _handleValueChange,
      placeholder: placeholder,
      icon: icon,
      isRequired: isRequired,
      errorMessage: errorMessage,
      keyboardType: TextInputType.numberWithOptions(
        decimal: isDecimal,
        signed: allowNegative,
      ),
      borderType: borderType,
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }
}

/// 使用 flutter_hooks 的日期选择器
class HookFormDatePickerField extends HookWidget {
  final String label;
  final int? value; // Milliseconds
  final ValueChanged<int?> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final bool showTime;
  final String? errorMessage;
  final FormFieldBorderType borderType;

  const HookFormDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onValueChange,
    this.placeholder = "yyyy/MM/dd",
    this.icon,
    this.isRequired = false,
    this.showTime = false,
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
  });

  void _showPicker(BuildContext context) {
    FocusScope.of(context).unfocus();

    final initialDate = value != null
        ? DateTime.fromMillisecondsSinceEpoch(value!)
        : DateTime.now();

    if (showTime) {
      _showDateTimePicker(context, initialDate);
    } else {
      _showDateOnlyPicker(context, initialDate);
    }
  }

  void _showDateOnlyPicker(BuildContext context, DateTime initialDate) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        DateTime tempDate = initialDate;
        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text("取消"),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  CupertinoButton(
                    child: const Text("确定"),
                    onPressed: () {
                      onValueChange(tempDate.millisecondsSinceEpoch);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  use24hFormat: true,
                  // 使用年-月-日顺序 (中文格式)
                  dateOrder: DatePickerDateOrder.ymd,
                  onDateTimeChanged: (DateTime newDate) {
                    tempDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDateTimePicker(BuildContext context, DateTime initialDate) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return _GenericDateTimePicker(
          initialDateTime: initialDate,
          mode: CupertinoDatePickerMode.dateAndTime,
          onConfirm: (dateTime) {
            onValueChange(dateTime.millisecondsSinceEpoch);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;

    String displayValue = "";
    if (value != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(value!);
      final format = showTime ? "yyyy/MM/dd HH:mm:ss" : "yyyy/MM/dd";
      displayValue = DateFormat(format).format(date);
    }

    return Column(
      children: [
        InkWell(
          onTap: () => _showPicker(context),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: FormFieldDefaults.minRowHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: FormFieldDefaults.horizontalPadding,
              vertical: FormFieldDefaults.verticalPadding,
            ),
            child: Row(
              children: [
                FormFieldLabelSection(
                    label: label, icon: icon, isRequired: isRequired),
                const SizedBox(width: FormFieldDefaults.spacing),
                Expanded(
                  child: Text(
                    displayValue.isEmpty
                        ? (showTime ? "yyyy/MM/dd HH:mm:ss" : placeholder)
                        : displayValue,
                    style: displayValue.isEmpty
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5))
                        : theme.textTheme.bodyMedium,
                  ),
                ),
                if (value != null) ...[
                  GestureDetector(
                    onTap: () => onValueChange(null),
                    child: Icon(
                      Icons.cancel,
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.date_range,
                  size: FormFieldDefaults.iconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              ],
            ),
          ),
        ),
        // 错误信息显示在分割线上方，贴着分割线
        if (hasError)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              right: FormFieldDefaults.horizontalPadding,
              bottom: 2,
            ),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error, fontSize: 10),
            ),
          ),
        FormDivider(
            type: borderType,
            color: hasError ? theme.colorScheme.error.withOpacity(0.5) : null),
      ],
    );
  }
}

/// 使用 flutter_hooks 的通用选择器
class HookFormPickerField extends HookWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onValueChange;
  final String placeholder;
  final IconData? icon;
  final bool isRequired;
  final String title;
  final String? errorMessage;
  final FormFieldBorderType borderType;

  const HookFormPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onValueChange,
    this.placeholder = "请选择",
    this.icon,
    this.isRequired = false,
    this.title = "请选择",
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
  });

  void _showPicker(BuildContext context) {
    FocusScope.of(context).unfocus();

    int initialIndex = options.indexOf(value);
    if (initialIndex < 0) initialIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        String tempValue = options.isNotEmpty ? options[initialIndex] : "";

        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text("取消"),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  CupertinoButton(
                    child: const Text("确定"),
                    onPressed: () {
                      onValueChange(tempValue);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 44,
                  scrollController:
                      FixedExtentScrollController(initialItem: initialIndex),
                  onSelectedItemChanged: (index) {
                    if (index >= 0 && index < options.length) {
                      tempValue = options[index];
                    }
                  },
                  children: options.map((e) => Center(child: Text(e))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: () => _showPicker(context),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: FormFieldDefaults.minRowHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: FormFieldDefaults.horizontalPadding,
              vertical: FormFieldDefaults.verticalPadding,
            ),
            child: Row(
              children: [
                FormFieldLabelSection(
                    label: label, icon: icon, isRequired: isRequired),
                const SizedBox(width: FormFieldDefaults.spacing),
                Expanded(
                  child: Text(
                    value.isEmpty ? placeholder : value,
                    style: value.isEmpty
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5))
                        : theme.textTheme.bodyMedium,
                  ),
                ),
                if (value.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => onValueChange(""),
                    child: Icon(
                      Icons.cancel,
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right,
                  size: FormFieldDefaults.iconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        // 错误信息显示在分割线上方，贴着分割线
        if (hasError)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              right: FormFieldDefaults.horizontalPadding,
              bottom: 2,
            ),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error, fontSize: 10),
            ),
          ),
        FormDivider(
            type: borderType,
            color: hasError ? theme.colorScheme.error.withOpacity(0.5) : null),
      ],
    );
  }
}

/// 使用 flutter_hooks 的多级联动选择器
class HookFormCascadePickerField extends HookWidget {
  final String label;
  final List<String> value;
  final CascadeOptions options;
  final ValueChanged<List<String>> onValueChange;
  final String placeholder;
  final IconData? icon;
  final String title;
  final String? errorMessage;
  final FormFieldBorderType borderType;
  final String separator;

  const HookFormCascadePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onValueChange,
    this.placeholder = "请选择",
    this.icon,
    this.title = "请选择",
    this.errorMessage,
    this.borderType = FormFieldBorderType.full,
    this.separator = " ",
  });

  void _showPicker(BuildContext context) {
    FocusScope.of(context).unfocus();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return _CascadePickerPopup(
          title: title,
          options: options,
          initialValue: value,
          onConfirm: (val) {
            onValueChange(val);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = value.join(separator);
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: () => _showPicker(context),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: FormFieldDefaults.minRowHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: FormFieldDefaults.horizontalPadding,
              vertical: FormFieldDefaults.verticalPadding,
            ),
            child: Row(
              children: [
                FormFieldLabelSection(label: label, icon: icon),
                const SizedBox(width: FormFieldDefaults.spacing),
                Expanded(
                  child: Text(
                    displayValue.isEmpty ? placeholder : displayValue,
                    style: displayValue.isEmpty
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5))
                        : theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (value.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => onValueChange([]),
                    child: Icon(
                      Icons.cancel,
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right,
                  size: FormFieldDefaults.iconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        // 错误信息显示在分割线上方，贴着分割线
        if (hasError)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              right: FormFieldDefaults.horizontalPadding,
              bottom: 2,
            ),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error, fontSize: 10),
            ),
          ),
        FormDivider(
            type: borderType,
            color: hasError ? theme.colorScheme.error.withOpacity(0.5) : null),
      ],
    );
  }
}

/// 自定义内容表单项
/// 允许用户完全自定义内容区域，同时保持统一的表单布局和验证样式
/// 自定义内容表单项
/// 允许用户完全自定义内容区域，同时保持统一的表单布局和验证样式
class FormCustomField<T> extends StatelessWidget {
  final String? label;
  final WidgetBuilder contentBuilder;
  final IconData? icon;
  final bool isRequired;
  final FormFieldBorderType borderType;

  /// 错误信息，支持 String 或 String? Function(BuildContext)
  final dynamic errorMessage;
  final Widget Function(BuildContext context)? helpBuilder;

  FormCustomField({
    Key? key,
    this.label,
    required this.contentBuilder,
    this.icon,
    this.isRequired = false,
    this.borderType = FormFieldBorderType.full,
    this.errorMessage,
    this.helpBuilder,
    this.fieldState,
  }) : super(key: key ?? fieldState?.key);

  /// 状态绑定构造函数
  FormCustomField.state({
    Key? key,
    required FormFieldState<T> state,
    this.label,
    this.isRequired = false,
    this.borderType = FormFieldBorderType.full,
    required this.contentBuilder,
    this.helpBuilder,
  })  : fieldState = state,
        errorMessage = null,
        icon = null,
        super(key: key ?? state.key);

  /// 可选的 FormFieldState 绑定
  final FormFieldState<T>? fieldState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = FormFieldConfig.maybeOf(context);

    final effectiveRowHeight =
        config?.rowHeight ?? FormFieldDefaults.minRowHeight;
    final effectiveHPadding =
        config?.horizontalPadding ?? FormFieldDefaults.horizontalPadding;
    final effectiveVPadding =
        config?.verticalPadding ?? FormFieldDefaults.verticalPadding;
    final effectiveSpacing = config?.spacing ?? FormFieldDefaults.spacing;

    // 错误信息逻辑
    final effectiveErrorMessage = errorMessage ??
        (fieldState?.hasInteracted == true ? fieldState?.errorMessage : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;
    final hasLabel = label != null && label!.isNotEmpty;
    final showLabelSection = hasLabel || icon != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(minHeight: effectiveRowHeight),
              padding: EdgeInsets.symmetric(
                horizontal: effectiveHPadding,
                vertical: effectiveVPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showLabelSection) ...[
                    FormFieldLabelSection(
                      label: label ?? '',
                      icon: icon,
                      isRequired: isRequired,
                      helperBuilder: helpBuilder,
                    ),
                    SizedBox(width: effectiveSpacing),
                  ],
                  Expanded(
                    child: contentBuilder(context),
                  ),
                ],
              ),
            ),
            FormDivider(
              type: borderType,
              color: hasError ? theme.colorScheme.error.withOpacity(0.5) : null,
            ),
          ],
        ),
        if (hasError)
          Positioned(
            bottom: 2,
            right: effectiveHPadding,
            child: Text(
              effectiveErrorMessage!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }
}
