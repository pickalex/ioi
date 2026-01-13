import 'package:flutter/foundation.dart';

extension SafeCast on Object? {
  String get castString {
    if (this is String) return this as String;
    _logWarning('String');
    return '';
  }

  double get castDouble {
    if (this is num) return (this as num).toDouble();
    if (this is String) {
      final val = double.tryParse(this as String);
      if (val != null) return val;
    }
    _logWarning('double');
    return 0.0;
  }

  int get castInt {
    if (this is num) return (this as num).toInt();
    if (this is String) {
      final val = int.tryParse(this as String);
      if (val != null) return val;
    }
    _logWarning('int');
    return 0;
  }

  bool get castBool {
    if (this is bool) return this as bool;
    _logWarning('bool');
    return false;
  }

  List<T> castList<T>(T Function(dynamic) fromJson) {
    if (this is List) {
      return (this as List).map(fromJson).toList();
    }
    _logWarning('List');
    return [];
  }

  void _logWarning(String expectedType) {
    if (kDebugMode) {
      debugPrint(
        '⚠️ [SafeCast] Expected $expectedType but got ${this?.runtimeType ?? "null"}: $this',
      );
    }
  }
}
