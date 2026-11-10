import 'dart:async';

/// A kill request does not acknowledge that a native invocation has exited.
/// Keep ownership until the worker's onExit notification; UI waits are bounded
/// separately by PosePreviewController.
class PoseWorkerTermination {
  final _exit = Completer<void>();
  bool get confirmed => _exit.isCompleted;
  void exited() {
    if (!_exit.isCompleted) _exit.complete();
  }

  Future<void> stopAndConfirm(void Function() requestStop) {
    requestStop();
    return _exit.future;
  }
}
