import 'dart:io';
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

  const UpdateInfo({
    required this.version,
    required this.currentVersion,
    required this.downloadUrl,
    required this.changelog,
  });
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

      final data = response.data as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      if (!isNewer(version, current)) return null;

      final assetName = _assetName(version);
      if (assetName.isEmpty) return null;

      final assets = data['assets'] as List? ?? [];
      String? downloadUrl;
      for (final asset in assets) {
        if ((asset['name'] as String?) == assetName) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      if (downloadUrl == null) return null;

      return UpdateInfo(
        version: version,
        currentVersion: current,
        downloadUrl: downloadUrl,
        changelog: data['body'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
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

    return savePath;
  }

  static Future<void> install(String filePath) async {
    if (Platform.isWindows) {
      await Process.start(filePath, [], runInShell: true);
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
    try {
      final attach = await Process.run('hdiutil', [
        'attach',
        dmgPath,
        '-nobrowse',
        '-quiet',
      ]);
      if (attach.exitCode != 0) {
        await Process.run('open', [dmgPath]);
        return;
      }

      // Find mount point
      final df = await Process.run('df', []);
      String? mountPoint;
      for (final line in (df.stdout as String).split('\n')) {
        if (line.contains('TakeIt')) {
          mountPoint = line.split(' ').last.trim();
          break;
        }
      }

      if (mountPoint == null) {
        await Process.run('open', [dmgPath]);
        return;
      }

      await Process.run('ditto', [
        '$mountPoint/TakeIt.app',
        '/Applications/TakeIt.app',
      ]);

      await Process.run('hdiutil', ['detach', mountPoint, '-quiet']);
      await Process.start('/Applications/TakeIt.app/Contents/MacOS/takeit', []);
      exit(0);
    } catch (e) {
      debugPrint('macOS install error: $e');
      await Process.run('open', [dmgPath]);
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
    return v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }
}
