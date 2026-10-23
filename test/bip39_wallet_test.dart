// Uji jalur frasa dompet: paket bip39 harus menghasilkan frasa 12 kata
// yang valid dan seed 64 byte yang cocok dengan vektor resmi BIP39.
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';

String hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('vektor resmi BIP39: abandon x11 + about -> seed kanonik', () {
    final mnemonic = List.filled(11, 'abandon').join(' ') + ' about';
    expect(bip39.validateMnemonic(mnemonic), isTrue);
    final seed = bip39.mnemonicToSeed(mnemonic);
    expect(seed.length, 64);
    expect(
      hexOf(seed),
      '5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc1'
      '9a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4',
    );
  });

  test('generateMnemonic: 12 kata valid, seed 64 byte deterministik', () {
    final mnemonic = bip39.generateMnemonic();
    expect(mnemonic.split(' ').length, 12);
    expect(bip39.validateMnemonic(mnemonic), isTrue);
    final a = bip39.mnemonicToSeed(mnemonic);
    final b = bip39.mnemonicToSeed(mnemonic);
    expect(a.length, 64);
    expect(hexOf(a), hexOf(b));
  });
}
