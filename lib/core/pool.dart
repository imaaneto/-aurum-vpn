import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

/// Limits how many core instances run at the same time across the app.
class Semaphore {
  Semaphore(this.max);
  int max;
  int _current = 0;
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  Future<void> acquire() async {
    if (_current < max) {
      _current++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
  }

  void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else if (_current > 0) {
      _current--;
    }
  }

  Future<T> run<T>(Future<T> Function() fn) async {
    await acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }
}

/// Runs [task] over [items] with at most [concurrency] in flight.
/// [shouldStop] is checked before each item; returning true ends early.
Future<void> runPool<T>(
  List<T> items,
  int concurrency,
  Future<void> Function(T item) task, {
  bool Function()? shouldStop,
}) async {
  if (items.isEmpty) return;
  var index = 0;
  Future<void> worker() async {
    while (true) {
      if (shouldStop != null && shouldStop()) return;
      if (index >= items.length) return;
      final item = items[index++];
      try {
        await task(item);
      } catch (_) {}
    }
  }

  await Future.wait(List.generate(min(concurrency, items.length), (_) => worker()));
}

/// TCP connect time in ms, -1 on failure.
Future<int> tcpPing(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
  final sw = Stopwatch()..start();
  try {
    final s = await Socket.connect(host, port, timeout: timeout);
    sw.stop();
    s.destroy();
    return max(1, sw.elapsedMilliseconds);
  } catch (_) {
    return -1;
  }
}
