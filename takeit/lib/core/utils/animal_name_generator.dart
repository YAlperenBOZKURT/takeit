import 'dart:math';

const _adjectives = [
  'Lazy',
  'Grumpy',
  'Clumsy',
  'Sneaky',
  'Fluffy',
  'Wobbly',
  'Chubby',
  'Dizzy',
  'Bouncy',
  'Sleepy',
  'Hungry',
  'Tiny',
  'Goofy',
  'Jumpy',
  'Sassy',
];

const _animals = [
  'Sloth',
  'Penguin',
  'Platypus',
  'Capybara',
  'Axolotl',
  'Narwhal',
  'Quokka',
  'Wombat',
  'Blobfish',
  'Tapir',
  'Pangolin',
  'Manatee',
  'Numbat',
  'Aye-aye',
  'Tardigrade',
  'Dugong',
  'Mudskipper',
  'Salamander',
  'Meerkat',
  'Echidna',
];

String generateAnimalName() {
  final random = Random();
  final adjective = _adjectives[random.nextInt(_adjectives.length)];
  final animal = _animals[random.nextInt(_animals.length)];
  return '$adjective$animal';
}
