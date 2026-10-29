import 'package:flutter_test/flutter_test.dart';
import 'package:nux_wallet/services/saved_invoices.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedInvoice _entry(String hash, int createdSecs, int expiresSecs,
        {BigInt? amount}) =>
    SavedInvoice(
      invoice: 'lntn-example-$hash',
      paymentHashHex: hash,
      amountMsat: amount ?? BigInt.from(5000000),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdSecs * 1000),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresSecs * 1000),
    );

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedInvoice json', () {
    test('roundtrip utuh', () {
      final e = _entry(_hashA, 1000, 4600);
      final back = SavedInvoice.fromJson(e.toJson());
      expect(back, isNotNull);
      expect(back!.invoice, e.invoice);
      expect(back.paymentHashHex, _hashA);
      expect(back.amountMsat, e.amountMsat);
      expect(back.createdAt, e.createdAt);
      expect(back.expiresAt, e.expiresAt);
    });

    test('entri rusak ditolak', () {
      expect(SavedInvoice.fromJson(null), isNull);
      expect(SavedInvoice.fromJson('teks'), isNull);
      expect(SavedInvoice.fromJson({'invoice': 'x'}), isNull);
      final e = _entry(_hashA, 1000, 4600).toJson();
      e['payment_hash'] = 'pendek';
      expect(SavedInvoice.fromJson(e), isNull);
    });
  });

  group('SavedInvoiceStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('simpan → muat urut terbaru, cari hash, hapus hash', () async {
      final store = SavedInvoiceStore();
      await store.save(_entry(_hashA, 1000, 4600));
      await store.save(_entry(_hashB, 2000, 5600));
      final list = await store.load();
      expect(list.length, 2);
      expect(list.first.paymentHashHex, _hashB);
      expect((await store.findByHash(_hashA))?.invoice,
          'lntn-example-$_hashA');
      expect(await store.findByHash('cc' * 32), isNull);
      await store.removeByHash(_hashA);
      expect((await store.load()).length, 1);
    });

    test('simpan hash yang sama = perbarui, bukan duplikat', () async {
      final store = SavedInvoiceStore();
      await store.save(_entry(_hashA, 1000, 4600));
      await store
          .save(_entry(_hashA, 1500, 5100, amount: BigInt.from(7000)));
      final list = await store.load();
      expect(list.length, 1);
      expect(list.single.amountMsat, BigInt.from(7000));
    });

    test('latestUnexpired melewati yang sudah kedaluwarsa', () async {
      final store = SavedInvoiceStore();
      await store.save(_entry(_hashA, 1000, 2000)); // mati di t=2000
      await store.save(_entry(_hashB, 1500, 9000)); // hidup s/d t=9000
      final at3000 = DateTime.fromMillisecondsSinceEpoch(3000 * 1000);
      expect((await store.latestUnexpired(now: at3000))?.paymentHashHex,
          _hashB);
      final at9500 = DateTime.fromMillisecondsSinceEpoch(9500 * 1000);
      expect(await store.latestUnexpired(now: at9500), isNull);
    });
  });
}
