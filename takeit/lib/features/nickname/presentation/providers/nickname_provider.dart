import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/settings_store.dart';
import '../../../../core/utils/animal_name_generator.dart';
import '../../../../main.dart';

final nicknameProvider = StateNotifierProvider<NicknameNotifier, String>((ref) {
  final initial = ref.read(initialNicknameProvider);
  return NicknameNotifier(initial, ref.read(settingsStoreProvider));
});

class NicknameNotifier extends StateNotifier<String> {
  final SettingsStore _store;

  NicknameNotifier(super.initial, this._store);

  Future<void> setNickname(String value) {
    state = value.trim();
    return _store.set('nickname', state);
  }

  void generateRandom() {
    state = generateAnimalName();
    _store.set('nickname', state);
  }

  bool get isValid => state.isNotEmpty;
}
