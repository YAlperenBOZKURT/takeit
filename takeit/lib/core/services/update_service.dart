import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Last-resort version used only if package_info fails to load. Should track
/// the `version:` field in pubspec.yaml; package_info is the real source.
const _fallbackVersion = '1.0.0';

class UpdateInfo {
  final String version;
  final String currentVersion;
  final String downloadUrl;
  final String changelog;

  /// URL of the release's `<asset>.sha256` file, when it has one.
  final String? checksumUrl;

  const UpdateInfo({
    required this.version,
    required this.currentVersion,
    required this.downloadUrl,
    required this.changelog,
    this.checksumUrl,
  });
}

/// The downloaded installer does not match the checksum published with the
/// release (truncated or corrupted download).
class UpdateIntegrityException implements Exception {
  @override
  String toString() =>
      'İndirilen güncelleme dosyası bozuk (sağlama toplamı eşleşmedi). '
      'Lütfen tekrar deneyin.';
}

class UpdateService {
  static const _apiUrl =
      'https://api.github.com/repos/YAlperenBOZKURT/takeit/releases/latest';

  static String? _cachedVersion;

  /// The running app's version, sourced from the build (pubspec.yaml) via
  /// package_info_plus. Cached after the first lookup.
  static Future<String> currentVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedVersion = info.version.isNotEmpty
          ? info.version
          : _fallbackVersion;
    } catch (_) {
      _cachedVersion = _fallbackVersion;
    }
    return _cachedVersion!;
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final current = await currentVersion();
      final dio = Dio();
      final response = await dio.get(
        _apiUrl,
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      return parseRelease(
        response.data as Map<String, dynamic>,
        currentVersion: current,
        assetNameFor: _assetName,
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  /// Builds the [UpdateInfo] for this platform from a GitHub "latest
  /// release" payload, or null when it is not newer or has no asset for us.
  @visibleForTesting
  static UpdateInfo? parseRelease(
    Map<String, dynamic> data, {
    required String currentVersion,
    required String Function(String version) assetNameFor,
  }) {
    final tagName = data['tag_name'] as String? ?? '';
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

    if (!isNewer(version, currentVersion)) return null;

    final assetName = assetNameFor(version);
    if (assetName.isEmpty) return null;

    String? urlOf(String name) {
      for (final asset in data['assets'] as List? ?? const []) {
        if ((asset['name'] as String?) == name) {
          return asset['browser_download_url'] as String?;
        }
      }
      return null;
    }

    final downloadUrl = urlOf(assetName);
    if (downloadUrl == null) return null;

    return UpdateInfo(
      version: version,
      currentVersion: currentVersion,
      downloadUrl: downloadUrl,
      changelog: data['body'] as String? ?? '',
      checksumUrl: urlOf('$assetName.sha256'),
    );
  }

  static Future<String> download(
    UpdateInfo info,
    void Function(double) onProgress,
    CancelToken cancelToken,
  ) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/${_assetName(info.version)}';

    final dio = Dio();
    await dio.download(
      info.downloadUrl,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );

    final checksumUrl = info.checksumUrl;
    if (checksumUrl != null) {
      final response = await dio.get<String>(
        checksumUrl,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.plain),
      );
      final expected = parseChecksumFile(response.data ?? '');
      if (expected == null || !await fileMatchesSha256(savePath, expected)) {
        try {
          await File(savePath).delete();
        } catch (_) {}
        throw UpdateIntegrityException();
      }
    } else {
      // Releases published before checksums were added have none.
      debugPrint('Update ${info.version} has no checksum — not verified');
    }

    return savePath;
  }

  /// Extracts the hex digest from a `sha256sum`-style line
  /// (`<64 hex chars>  <file name>`), or null if there is none.
  @visibleForTesting
  static String? parseChecksumFile(String content) {
    final match = RegExp(r'\b([0-9a-fA-F]{64})\b').firstMatch(content);
    return match?.group(1)!.toLowerCase();
  }

  /// Whether the SHA-256 of the file at [path] equals [expectedHex].
  /// Streams the file, so large installers are not loaded into memory.
  @visibleForTesting
  static Future<bool> fileMatchesSha256(String path, String expectedHex) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString() == expectedHex.toLowerCase();
  }

  /// Sweeps installer files left over from a previous update attempt.
  ///
  /// Safe to call on every launch: by the time the app runs again, any prior
  /// install either completed (this process IS the new version) or was
  /// abandoned, so nothing still needs that file. Deliberately skips the
  /// Linux tar.gz — that one is never auto-installed, the user has to open
  /// and act on it themselves, so removing it could delete something they
  /// still meant to extract.
  static Future<void> cleanupStaleInstallers() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final isInstaller =
            (name.startsWith('TakeIt-Setup-') && name.endsWith('.exe')) ||
            (name.startsWith('TakeIt-') && name.endsWith('.apk')) ||
            (name.startsWith('TakeIt-') && name.endsWith('.dmg'));
        if (!isInstaller) continue;
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<void> install(String filePath) async {
    if (Platform.isWindows) {
      // Launch the installer directly (no cmd.exe in between, which also
      // mangles paths with spaces) and let it outlive this process.
      await Process.start(filePath, [], mode: ProcessStartMode.detached);
      exit(0);
    } else if (Platform.isAndroid) {
      // OpenFilex only launches the system package installer — it doesn't
      // throw when that fails (permission denied, no handler, bad file), it
      // just returns a non-"done" result. Ignoring that result is why a
      // failed install used to look identical to a successful one: the
      // dialog closed either way with nothing telling the user to retry.
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } else if (Platform.isMacOS) {
      await _installMacOS(filePath);
    } else if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [
        File(filePath).parent.path,
      ]);
      if (result.exitCode != 0) {
        throw Exception('xdg-open failed: ${result.stderr}');
      }
    }
  }

  static Future<void> _installMacOS(String dmgPath) async {
    const target = '/Applications/TakeIt.app';
    const staging = '/Applications/.TakeIt.app.updating';
    String? mountPoint;
    try {
      // Mount at a directory we choose instead of fishing it out of `df`
      // output (which broke on volume names with spaces).
      mountPoint = (await Directory.systemTemp.createTemp('takeit-dmg-')).path;
      final attach = await Process.run('hdiutil', [
        'attach',
        dmgPath,
        '-nobrowse',
        '-quiet',
        '-mountpoint',
        mountPoint,
      ]);
      if (attach.exitCode != 0) {
        mountPoint = null;
        await Process.run('open', [dmgPath]);
        return;
      }

      final bundle = Directory(mountPoint)
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.toLowerCase().endsWith('.app'))
          .firstOrNull;
      if (bundle == null) {
        await Process.run('open', [dmgPath]);
        return;
      }

      // Copy next to the old app first and only swap once the copy
      // succeeded, so a failed copy never leaves a half-written app.
      await Process.run('rm', ['-rf', staging]);
      final copy = await Process.run('ditto', [bundle.path, staging]);
      if (copy.exitCode != 0) {
        debugPrint('macOS update copy failed: ${copy.stderr}');
        await Process.run('rm', ['-rf', staging]);
        await Process.run('open', [dmgPath]);
        return;
      }
      await Process.run('rm', ['-rf', target]);
      await Directory(staging).rename(target);

      // exit() skips `finally`, so detach before relaunching.
      await Process.run('hdiutil', ['detach', mountPoint, '-quiet']);
      mountPoint = null;
      await Process.run('open', ['-n', target]);
      exit(0);
    } catch (e) {
      debugPrint('macOS install error: $e');
      await Process.run('open', [dmgPath]);
    } finally {
      if (mountPoint != null) {
        await Process.run('hdiutil', ['detach', mountPoint, '-quiet']);
      }
    }
  }

  static String _assetName(String version) {
    if (Platform.isWindows) return 'TakeIt-Setup-$version.exe';
    if (Platform.isAndroid) return 'TakeIt-$version.apk';
    if (Platform.isMacOS) return 'TakeIt-$version.dmg';
    if (Platform.isLinux) return 'TakeIt-$version-linux-x64.tar.gz';
    return '';
  }

  @visibleForTesting
  static bool isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    // Ignore pre-release/build suffixes ("1.2.0-beta.1", "1.2.0+7").
    final core = v.split(RegExp(r'[-+]')).first;
    return core.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }
}
