import 'package:flutter/material.dart';

/// 表单字段状态
/// 用于管理单个字段的值、验证状态、错误信息
/// 同时可以持有控制器引用，方便外部操作
class FormFieldState<T> extends ChangeNotifier {
  T _value;
  String? _errorMessage;
  bool _hasInteracted = false;
  final List<FormValidator<T>> validators;

  // 控制器引用 (由字段组件绑定)
  TextEditingController? _controller;
  FocusNode? _focusNode;
  VoidCallback? _showPicker;

  // 内部存储初始值，允许为 null 以兼容 Hot Reload 期间的状态不一致
  final T? _initialValue;

  /// 可选的 ID，主要用于调试或查找
  final String? id;

  /// 绑定的 Key
  /// 直接使用 [ObjectKey] 绑定当前实例 [this]
  /// 这确保了 Key 的唯一性（绝对不会重复，除非是同一个对象），也确保了 Widget 与 State 的强绑定
  late final Key key = ObjectKey(this);

  FormFieldState({
    required T initialValue,
    this.validators = const [],
    this.id,
  })  : _value = initialValue,
        // 显式赋值，确保新实例有值
        _initialValue = initialValue;

  T get value => _value;
  String? get errorMessage => _errorMessage;
  bool get hasInteracted => _hasInteracted;

  /// 是否有效（无错误）
  bool get isValid => _errorMessage == null;

  // 控制器引用 getter
  TextEditingController? get controller => _controller;
  FocusNode? get focusNode => _focusNode;

  /// 绑定控制器引用 (由字段组件内部调用)
  void bindController(TextEditingController? controller) {
    _controller = controller;
  }

  /// 绑定焦点节点 (由字段组件内部调用)
  void bindFocusNode(FocusNode? focusNode) {
    _focusNode = focusNode;
  }

  /// 绑定 showPicker 方法 (由 Picker 组件内部调用)
  void bindShowPicker(VoidCallback? showPicker) {
    _showPicker = showPicker;
  }

  // ========== 便捷方法 ==========

  /// 聚焦到此字段
  void focus() => _focusNode?.requestFocus();

  /// 取消聚焦
  void unfocus() => _focusNode?.unfocus();

  /// 清空输入内容
  void clear() {
    _controller?.clear();
    if (_value is String) {
      didChange('' as T);
    }
  }

  /// 打开 Picker (适用于 Picker 类型字段)
  void openPicker() => _showPicker?.call();

  /// 更新值
  void didChange(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      _hasInteracted = true;
      // 输入时清除错误
      if (_errorMessage != null) {
        _errorMessage = null;
      }
      notifyListeners();
    }
  }

  /// 标记为已交互
  void didInteract() {
    if (!_hasInteracted) {
      _hasInteracted = true;
      notifyListeners();
    }
  }

  /// 设置错误信息（外部强制设置）
  void setError(String? error) {
    if (_errorMessage != error) {
      _errorMessage = error;
      notifyListeners();
    }
  }

  /// 执行验证，返回是否有效
  bool validate() {
    _hasInteracted = true;
    for (final validator in validators) {
      final error = validator(_value);
      if (error != null) {
        _errorMessage = error;
        notifyListeners();
        return false;
      }
    }

    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
    return true;
  }

  /// 重置状态
  void reset([T? newValue]) {
    // 优先使用传入的新值
    if (newValue != null) {
      _value = newValue;
    } else {
      // 如果没有传入新值，尝试恢复初始值
      if (_initialValue != null) {
        _value = _initialValue as T;
      } else {
        // _initialValue 为 null 的情况：
        // 1. 初始值本来就是 null (且 T 允许 null)，比如 int? 生日
        // 2. Hot Reload 导致 _initialValue 丢失 (且 T 不允许 null)

        if (null is T) {
          // T 是 nullable 类型，安全重置为 null
          _value = null as T;
        } else if (_value is String) {
          // T 是 String (非空)，但在 Hot Reload 中丢失初始值，回退到空串
          _value = '' as T;
        }
        // 其他非空类型如果丢失初始值，保持当前值以防 crash
      }
    }

    _errorMessage = null;
    _hasInteracted = false;

    // 如果是文本字段且有控制器，需要同步清空/更新
    if (_controller != null) {
      if (_value is String) {
        _controller!.text = _value as String;
      } else if (_value == null) {
        _controller!.text = "";
      }
    }

    notifyListeners();
  }
}

/// 表单验证器类型定义
typedef FormValidator<T> = String? Function(T value);

/// 常用验证器
class FormValidators {
  /// 必填验证器
  static FormValidator<String> required({String message = "此项为必填"}) {
    return (value) {
      if (value.trim().isEmpty) return message;
      return null;
    };
  }

  /// 必选验证器 (针对 Object/List 等)
  static FormValidator<T> requiredValue<T>({String message = "此项为必填"}) {
    return (value) {
      if (value == null) return message;
      if (value is List && value.isEmpty) return message;
      return null;
    };
  }

  /// 最小长度验证器
  static FormValidator<String> minLength(int min, {String? message}) {
    return (value) {
      if (value.length < min) {
        return message ?? "最少需要$min个字符";
      }
      return null;
    };
  }

  /// 最大长度验证器
  static FormValidator<String> maxLength(int max, {String? message}) {
    return (value) {
      if (value.length > max) {
        return message ?? "最多$max个字符";
      }
      return null;
    };
  }

  /// 正则验证器
  static FormValidator<String> pattern(RegExp regex,
      {required String message}) {
    return (value) {
      if (value.isNotEmpty && !regex.hasMatch(value)) return message;
      return null;
    };
  }

  /// 邮箱验证器
  static FormValidator<String> email({String message = "请输入有效的邮箱地址"}) {
    final emailRegex = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return pattern(emailRegex, message: message);
  }

  /// 手机号验证器
  static FormValidator<String> phone({String message = "请输入有效的手机号"}) {
    final phoneRegex = RegExp(r"^1[3-9]\d{9}$");
    return pattern(phoneRegex, message: message);
  }
}

/// 表单状态管理器
/// 用于统一管理多个字段的验证
class FormStateHelper extends ChangeNotifier {
  final List<FormFieldState> fields;

  FormStateHelper(this.fields) {
    for (var field in fields) {
      // 监听每个字段的变化，以便 FormStateHelper 的监听者也能收到通知（可选）
      field.addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    for (var field in fields) {
      field.removeListener(notifyListeners);
    }
    super.dispose();
  }

  /// 所有字段是否都有效
  bool get isValid => fields.every((field) => field.isValid);

  /// 是否有任何字段被修改过
  bool get hasInteracted => fields.any((field) => field.hasInteracted);

  /// 验证所有字段，返回是否全部有效
  /// 会自动清除焦点（收起键盘）
  bool validateAll() {
    // 收起键盘（使用 FocusManager，无需 context）
    FocusManager.instance.primaryFocus?.unfocus();

    var allValid = true;
    for (var field in fields) {
      if (!field.validate()) {
        allValid = false;
      }
    }
    return allValid;
  }

  /// 重置所有字段
  void resetAll() {
    for (var field in fields) {
      field.reset();
    }
  }
}
