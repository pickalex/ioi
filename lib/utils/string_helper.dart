/// String 可空扩展
extension StringNullableExtension on String? {
  /// 判断是否为空
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// 判断是否不为空
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;

  /// 获取值或默认值
  String get valueOrDefault => this ?? '';

  /// 隐藏手机号中间四位
  String hideMobile() {
    if (this == null || this!.length != 11) return this ?? '';
    return this!.replaceFirst(RegExp(r'\d{4}'), '****', 3);
  }
}


extension StringListExtension on List<String?> {
  /// 过滤空值并拼接
  String joinSkipNull({String separator = ','}) {
    return where((e) => e != null && e.isNotEmpty).join(separator);
  }
}
