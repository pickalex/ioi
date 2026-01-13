import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

/// 节流 + 丢弃 (Droppable): 在 duration 内忽略新事件；且如果当前处理过程中有新事件，也忽略（直到处理完成）。
/// 适用于：下拉刷新、表单提交（防止重复点击）。
EventTransformer<E> throttleDroppable<E>(Duration duration) {
  return (events, mapper) {
    return droppable<E>().call(events.throttle(duration), mapper);
  };
}

/// 节流 + 重启 (Restartable/Switch): 在 duration 内忽略新事件；但如果通过了节流，则取消上一个正在进行的任务，开始新的。
/// 适用于：搜索框输入（只关注最新的输入）。
EventTransformer<E> throttleRestartable<E>(Duration duration) {
  return (events, mapper) {
    return restartable<E>().call(events.throttle(duration), mapper);
  };
}

EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}
