import 'package:intl/intl.dart';
import '../services/stock_service.dart';

extension DateTimeExtension on DateTime {
  /// 格式化为: 2023-10-25
  String get dateString {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  /// 格式化为: 14:30
  String get timeString {
    return DateFormat('HH:mm').format(this);
  }

  /// 格式化为: 2023-10-25 14:30
  String get dateTimeString {
    return DateFormat('yyyy-MM-dd HH:mm').format(this);
  }

  /// 获取相对时间描述
  /// 例如：刚刚, 5分钟前, 昨天 14:30, 10-25 14:30
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24 && isSameDay(now)) {
      return '${difference.inHours}小时前';
    } else if (isYesterday(now)) {
      return '昨天 $timeString';
    } else if (isSameYear(now)) {
      return DateFormat('MM-dd HH:mm').format(this);
    } else {
      return dateTimeString;
    }
  }

  /// 判断是否同一天
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// 判断是否昨天
  bool isYesterday(DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return isSameDay(yesterday);
  }

  /// 判断是否同一年
  bool isSameYear(DateTime other) {
    return year == other.year;
  }

  /// 判断是否在 A 股交易时间内
  bool get isMarketOpen {
    // 周末不交易
    if (weekday == DateTime.saturday || weekday == DateTime.sunday)
      return false;

    // 动态节假日检查
    if (StockService().isHoliday(this)) return false;

    final totalMinutes = hour * 60 + minute;
    // 9:15 - 11:30 (包含开盘前集合竞价)
    if (totalMinutes >= 9 * 60 + 15 && totalMinutes <= 11 * 60 + 30)
      return true;
    // 13:00 - 15:00
    if (totalMinutes >= 13 * 60 && totalMinutes <= 15 * 00) return true;

    return false;
  }

  /// 判断是否在此之前的几分钟内 (用于判断是否刚收盘)
  bool isWithinMinutes(int minutes) {
    final now = DateTime.now();
    return now.difference(this).inMinutes.abs() <= minutes;
  }
}

extension IntExtension on int {
  /// 毫秒时间戳转 DateTime
  DateTime get toDateTime => DateTime.fromMillisecondsSinceEpoch(this);

  /// 秒时间戳转 DateTime
  DateTime get toDateTimeFromSeconds =>
      DateTime.fromMillisecondsSinceEpoch(this * 1000);
}
