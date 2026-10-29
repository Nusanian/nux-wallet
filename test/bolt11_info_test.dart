import 'package:flutter_test/flutter_test.dart';
import 'package:nux_wallet/utils/bolt11_info.dart';

/// Invoice uji JIT testnet asli (nominal 5.000 nusan, deskripsi
/// "uji JIT NUX"). Nilai hash + kedaluwarsa yang diharapkan di bawah
/// diverifikasi dengan decoder Python independen, bukan dari kode
/// Dart yang diuji.
const _invoice =
    'lntn50u1p4dtvwydqjw44xjgz2f92zqnj4tqpp56e07u6ce6ryn9q094a8mlj2nv4ycaxl4fevez4wy48dvh2t5cjpqsp5pu2ya79p07tltuvnkfn6wszvcs5aqjqw8ptsaz0896q722632lfq9qyysgqcqzpvxqrrssrzjq2mf6clh7pmk2ftaw2d5zs2zd2llsz53pz8tgw0vduhfv6dkgg65jqqqqyqq2xsqqcqqqqqqqqqqqqqqfqgczp89wecast6hl4eymf8hlrt2zpw6x52qc4hgt0vsf2yh2h5j3xjcth7k8csyyvpanydw8v6xwxgkm74qtcw3aumxm8gkvcfhwf2ggq24yfp8';

void main() {
  group('parseBolt11Info', () {
    test('invoice asli: hash + kedaluwarsa terbaca benar', () {
      final info = parseBolt11Info(_invoice);
      expect(info, isNotNull);
      expect(info!.paymentHashHex,
          'd65fee6b19d0c93281e5af4fbfc95365498e9bf54e599155c4a9dacba974c482');
      // timestamp invoice 1792389572 + expiry 3600 detik.
      expect(info.expiresAt.millisecondsSinceEpoch, 1792393172 * 1000);
      expect(
          info.isExpiredAt(
              DateTime.fromMillisecondsSinceEpoch(1792393171 * 1000)),
          isFalse);
      expect(
          info.isExpiredAt(
              DateTime.fromMillisecondsSinceEpoch(1792393172 * 1000)),
          isTrue);
    });

    test('satu karakter diubah: checksum rusak → null', () {
      final corrupted = '${_invoice.substring(0, 40)}q${_invoice.substring(41)}';
      expect(parseBolt11Info(corrupted), isNull);
    });

    test('masukan bukan invoice → null', () {
      expect(parseBolt11Info(''), isNull);
      expect(parseBolt11Info('bukan invoice'), isNull);
      expect(parseBolt11Info('ln'), isNull);
      expect(parseBolt11Info('lntn1qqqqqq'), isNull);
    });
  });
}
