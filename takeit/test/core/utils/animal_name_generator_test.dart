import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/utils/animal_name_generator.dart';

void main() {
  group('generateAnimalName', () {
    test('returns a non-empty CamelCase name', () {
      final name = generateAnimalName();
      expect(name, isNotEmpty);
      // Starts with an uppercase adjective.
      expect(name[0], matches(RegExp(r'[A-Z]')));
    });

    test('combines a known adjective with a known animal', () {
      // Run many times to exercise the random combinations.
      for (var i = 0; i < 200; i++) {
        final name = generateAnimalName();
        // There must be at least two capital letters (adjective + animal),
        // since both lists are capitalized.
        final capitals = RegExp(r'[A-Z]').allMatches(name).length;
        expect(
          capitals,
          greaterThanOrEqualTo(2),
          reason: 'Generated "$name" should join two capitalized words',
        );
      }
    });

    test('produces variety across many calls', () {
      final names = <String>{};
      for (var i = 0; i < 100; i++) {
        names.add(generateAnimalName());
      }
      // With 15 adjectives x 20 animals = 300 combos, 100 calls should yield
      // more than a handful of distinct values.
      expect(names.length, greaterThan(5));
    });
  });
}
