import 'dart:async';
import 'package:flutter/foundation.dart';

class Debouncer {
  static final Map<String, Timer> _timers = {};
  
  static void run({
    String tag = 'defualt_tag',
    required VoidCallback action,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    if (_timers.containsKey(tag)) {
      _timers[tag]?.cancel();
    }
    _timers[tag] = Timer(duration, () {
      _timers.remove(tag);
      action();
    });
  }


  static void cancel(String tag) {
    if (_timers.containsKey(tag)) {
      _timers[tag]?.cancel();
      _timers.remove(tag);
    }
  }

  static void cancelAll() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}


class Throttler {
  static final Map<String, int> _lastRunTime = {};

  static void run({
    String tag = 'defualt_tag',
    required VoidCallback action,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastRunTime[tag] ?? 0;

    if (now - lastTime > duration.inMilliseconds) {
      _lastRunTime[tag] = now;
      action();
    }
  }

  static void reset(String tag) {
    _lastRunTime.remove(tag);
  }
}
