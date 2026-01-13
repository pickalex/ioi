import 'dart:async';
import 'dart:isolate';

/// A pool of persistent isolates for background computation.
/// Avoids the overhead of creating/destroying isolates for each task.
class IsolatePool<T, R> {
  final int size;
  final R Function(T) computation;
  final List<_IsolateWorker<T, R>> _workers = [];
  final List<Completer<_IsolateWorker<T, R>>> _waitingQueue = [];
  bool _isInitialized = false;
  bool _isDisposed = false;

  IsolatePool({required this.size, required this.computation});

  /// Initialize the pool by spawning isolates
  Future<void> init() async {
    if (_isInitialized || _isDisposed) return;

    for (int i = 0; i < size; i++) {
      final worker = await _IsolateWorker.spawn<T, R>(computation, i);
      _workers.add(worker);
    }
    _isInitialized = true;
  }

  /// Execute a computation on an available worker
  Future<R> execute(T data) async {
    if (_isDisposed) {
      throw StateError('IsolatePool has been disposed');
    }
    if (!_isInitialized) {
      await init();
    }

    final worker = await _acquireWorker();
    try {
      return await worker.compute(data);
    } finally {
      _releaseWorker(worker);
    }
  }

  /// Execute multiple computations in parallel
  Future<List<R>> executeAll(List<T> dataList) async {
    if (_isDisposed) {
      throw StateError('IsolatePool has been disposed');
    }
    if (!_isInitialized) {
      await init();
    }

    final futures = dataList.map((data) => execute(data));
    return Future.wait(futures);
  }

  Future<_IsolateWorker<T, R>> _acquireWorker() async {
    // Find an available worker
    for (final worker in _workers) {
      if (!worker._isBusy) {
        worker._isBusy = true;
        return worker;
      }
    }

    // All workers busy, wait for one to become available
    final completer = Completer<_IsolateWorker<T, R>>();
    _waitingQueue.add(completer);
    return completer.future;
  }

  void _releaseWorker(_IsolateWorker<T, R> worker) {
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeAt(0);
      completer.complete(worker);
    } else {
      worker._isBusy = false;
    }
  }

  /// Dispose all isolates
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // Cancel any waiting tasks
    for (final completer in _waitingQueue) {
      completer.completeError(StateError('IsolatePool disposed'));
    }
    _waitingQueue.clear();

    // Kill all workers
    for (final worker in _workers) {
      await worker.dispose();
    }
    _workers.clear();
  }
}

class _IsolateWorker<T, R> {
  final int id;
  final Isolate _isolate;
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  bool _isBusy = false;

  // Use a queue to track pending responses
  final List<Completer<dynamic>> _pendingCompleters = [];
  StreamSubscription? _subscription;

  _IsolateWorker._({
    required this.id,
    required Isolate isolate,
    required SendPort sendPort,
    required ReceivePort receivePort,
  }) : _isolate = isolate,
       _sendPort = sendPort,
       _receivePort = receivePort {
    // Listen to responses and complete pending futures
    _subscription = _receivePort.listen((message) {
      if (_pendingCompleters.isNotEmpty) {
        final completer = _pendingCompleters.removeAt(0);
        completer.complete(message);
      }
    });
  }

  static Future<_IsolateWorker<T, R>> spawn<T, R>(
    R Function(T) computation,
    int id,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint<T, R>,
      _IsolateInitData<T, R>(
        sendPort: receivePort.sendPort,
        computation: computation,
      ),
    );

    // Wait for the isolate to send its SendPort
    final sendPort = await receivePort.first as SendPort;

    return _IsolateWorker._(
      id: id,
      isolate: isolate,
      sendPort: sendPort,
      receivePort: receivePort,
    );
  }

  Future<R> compute(T data) async {
    final completer = Completer<dynamic>();
    _pendingCompleters.add(completer);
    _sendPort.send(data);

    final result = await completer.future;
    if (result is _IsolateError) {
      throw result.error;
    }
    return result as R;
  }

  Future<void> dispose() async {
    _sendPort.send(_IsolateShutdown());
    await _subscription?.cancel();
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);

    // Complete any pending completers with error
    for (final completer in _pendingCompleters) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Worker disposed'));
      }
    }
    _pendingCompleters.clear();
  }
}

class _IsolateInitData<T, R> {
  final SendPort sendPort;
  final R Function(T) computation;

  _IsolateInitData({required this.sendPort, required this.computation});
}

class _IsolateShutdown {}

class _IsolateError {
  final Object error;
  _IsolateError(this.error);
}

void _isolateEntryPoint<T, R>(_IsolateInitData<T, R> initData) {
  final receivePort = ReceivePort();
  initData.sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is _IsolateShutdown) {
      receivePort.close();
      return;
    }

    try {
      final result = initData.computation(message as T);
      initData.sendPort.send(result);
    } catch (e) {
      initData.sendPort.send(_IsolateError(e));
    }
  });
}
