import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/services/transfer_keep_alive.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Records every toggle so tests can assert exactly when the wakelock is
/// engaged and released.
class _FakeWakelock extends WakelockPlusPlatformInterface {
  final List<bool> toggles = [];
  bool _enabled = false;

  @override
  Future<void> toggle({required bool enable}) async {
    toggles.add(enable);
    _enabled = enable;
  }

  @override
  Future<bool> get enabled async => _enabled;
}

void main() {
  late _FakeWakelock wakelock;

  setUp(() {
    wakelock = _FakeWakelock();
    // WakelockPlus routes through this lazily-cached top-level variable, not
    // through WakelockPlusPlatformInterface.instance — it's the package's
    // intended test seam and must be reassigned per test.
    wakelockPlusPlatformInstance = wakelock;
    TransferKeepAlive.resetForTesting();
  });

  test('engages on first active source and releases when it goes idle', () {
    TransferKeepAlive.setActive('room', true);
    expect(wakelock.toggles, [true]);

    TransferKeepAlive.setActive('room', false);
    expect(wakelock.toggles, [true, false]);
  });

  test('one source finishing does not release the other\'s lock', () {
    TransferKeepAlive.setActive('room', true);
    TransferKeepAlive.setActive('quick', true);
    expect(wakelock.toggles, [
      true,
    ], reason: 'second source must not re-enable');

    // Room finishes while quick is still transferring — lock must hold.
    TransferKeepAlive.setActive('room', false);
    expect(wakelock.toggles, [true]);

    TransferKeepAlive.setActive('quick', false);
    expect(wakelock.toggles, [true, false]);
  });

  test('redundant reports do not thrash the wakelock', () {
    TransferKeepAlive.setActive('quick', true);
    TransferKeepAlive.setActive('quick', true);
    TransferKeepAlive.setActive('quick', true);
    expect(wakelock.toggles, [true]);

    TransferKeepAlive.setActive('quick', false);
    TransferKeepAlive.setActive('quick', false);
    expect(wakelock.toggles, [true, false]);
  });

  test('reporting idle for a source that never ran does nothing', () {
    TransferKeepAlive.setActive('room', false);
    expect(wakelock.toggles, isEmpty);
  });
}
