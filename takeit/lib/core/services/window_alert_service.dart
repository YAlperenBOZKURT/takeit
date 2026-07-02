import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

// ── Win32 FFI bindings (Windows only) ──

final _user32 = Platform.isWindows ? DynamicLibrary.open('user32.dll') : null;

// FindWindowW(LPCWSTR lpClassName, LPCWSTR lpWindowName) -> HWND
typedef _FindWindowW =
    IntPtr Function(Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
typedef _FindWindowWDart =
    int Function(Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
final _findWindow = Platform.isWindows
    ? _user32!.lookupFunction<_FindWindowW, _FindWindowWDart>('FindWindowW')
    : null;

// FlashWindow(HWND hWnd, BOOL bInvert) -> BOOL
typedef _FlashWindowNative = Int32 Function(IntPtr hWnd, Int32 bInvert);
typedef _FlashWindowDart = int Function(int hWnd, int bInvert);
final _flashWindowSimple = Platform.isWindows
    ? _user32!.lookupFunction<_FlashWindowNative, _FlashWindowDart>(
        'FlashWindow',
      )
    : null;

// MessageBeep(UINT uType) -> BOOL
typedef _MessageBeepNative = Int32 Function(Uint32 uType);
typedef _MessageBeepDart = int Function(int uType);
final _messageBeep = Platform.isWindows
    ? _user32!.lookupFunction<_MessageBeepNative, _MessageBeepDart>(
        'MessageBeep',
      )
    : null;

const int _mbIconAsterisk = 0x00000040;

/// Flashes the taskbar icon on desktop platforms when the window is not focused.
class WindowAlertService {
  static bool _initialized = false;
  static int _hwnd = 0;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static Future<void> init() async {
    if (!_isDesktop || _initialized) return;
    _initialized = true;
    await windowManager.ensureInitialized();

    if (Platform.isWindows && _findWindow != null) {
      final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
      final windowName = 'TakeIt'.toNativeUtf16();
      _hwnd = _findWindow!(className, windowName);
      calloc.free(className);
      calloc.free(windowName);
    }
  }

  /// Flash taskbar / bounce dock icon to get user attention
  static Future<void> flashWindow() async {
    if (!_isDesktop || !_initialized) return;
    try {
      final isFocused = await windowManager.isFocused();
      if (isFocused) return;

      if (Platform.isWindows && _hwnd != 0 && _flashWindowSimple != null) {
        // Real Win32 taskbar flash (orange blink)
        for (var i = 0; i < 5; i++) {
          _flashWindowSimple!(_hwnd, 1);
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        // macOS / Linux fallback
        await windowManager.setAlwaysOnTop(true);
        await Future.delayed(const Duration(milliseconds: 300));
        await windowManager.setAlwaysOnTop(false);
      }
    } catch (e) {
      debugPrint('WindowAlertService: $e');
    }
  }

  /// Play the system notification sound on Windows
  static void playSound() {
    if (Platform.isWindows && _messageBeep != null) {
      _messageBeep!(_mbIconAsterisk);
    }
  }
}
