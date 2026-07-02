import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/utils/animal_name_generator.dart';
import '../../../../main.dart';

final nicknameProvider = StateNotifierProvider<NicknameNotifier, String>((ref) {
  final initial = ref.read(initialNicknameProvider);
  return NicknameNotifier(initial);
});

class NicknameNotifier extends StateNotifier<String> {
  NicknameNotifier(super.initial);

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> setNickname(String value) async {
    state = value.trim();
    await _save();
  }

  void generateRandom() {
    state = generateAnimalName();
    _save();
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      Map<String, dynamic> existing = {};
      try {
        if (await file.exists()) {
          existing =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        }
      } catch (_) {}
      existing['nickname'] = state;
      await file.writeAsString(jsonEncode(existing));
    } catch (_) {}
  }

  bool get isValid => state.isNotEmpty;
}
