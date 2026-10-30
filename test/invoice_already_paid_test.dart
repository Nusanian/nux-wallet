import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:ldk_node/src/generated/lib.dart';
import 'package:nux_wallet/services/lsp_service.dart';

PaymentHash _hash(int byte) =>
    PaymentHash(data: U8Array32(Uint8List.fromList(List.filled(32, byte))));

String _hex(int byte) => List.filled(32, byte)
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();

PaymentDetails _jitPayment({
  required int hashByte,
  required PaymentStatus status,
  PaymentDirection direction = PaymentDirection.inbound,
}) {
  return PaymentDetails(
    id: PaymentId(data: Uint8List.fromList([1, 2, 3])),
    kind: PaymentKind_Bolt11Jit(
      hash: _hash(hashByte),
      lspFeeLimits: const LSPFeeLimits(),
    ),
    amountMsat: BigInt.from(4975000),
    direction: direction,
    status: status,
    latestUpdateTimestamp: BigInt.from(1700000000),
  );
}

PaymentDetails _regularPayment({
  required int hashByte,
  required PaymentStatus status,
  PaymentDirection direction = PaymentDirection.inbound,
}) {
  return PaymentDetails(
    id: PaymentId(data: Uint8List.fromList([4, 5, 6])),
    kind: PaymentKind_Bolt11(hash: _hash(hashByte)),
    amountMsat: BigInt.from(995000),
    direction: direction,
    status: status,
    latestUpdateTimestamp: BigInt.from(1700000000),
  );
}

void main() {
  group('invoiceAlreadyPaid (rekonsiliasi simpanan invoice)', () {
    test('kasus lapangan: invoice JIT lunas saat user di layar lain '
        '→ terdeteksi lunas, tidak boleh dipulihkan sebagai unpaid',
        () {
      // Pembayaran diterima dengan benar (Riwayat menampilkannya
      // sebagai received dan saldo bertambah), tetapi simpanan
      // lokal invoice-nya belum terhapus karena pengawas event
      // layar Terima tidak sedang berjalan. Keputusan pemulihan
      // harus membaca catatan node yang sama.
      final payments = [
        _jitPayment(hashByte: 7, status: PaymentStatus.succeeded),
      ];
      expect(invoiceAlreadyPaid(payments, _hex(7)), isTrue);
    });

    test('invoice biasa (Jalur 1) masuk succeeded → lunas', () {
      final payments = [
        _regularPayment(hashByte: 9, status: PaymentStatus.succeeded),
      ];
      expect(invoiceAlreadyPaid(payments, _hex(9)), isTrue);
    });

    test('invoice yang sama masih pending → belum lunas, tetap '
        'dipulihkan', () {
      final payments = [
        _jitPayment(hashByte: 7, status: PaymentStatus.pending),
      ];
      expect(invoiceAlreadyPaid(payments, _hex(7)), isFalse);
    });

    test('percobaan pembayaran masuk gagal → belum lunas (invoice '
        'masih bisa dibayar lagi)', () {
      final payments = [
        _jitPayment(hashByte: 7, status: PaymentStatus.failed),
      ];
      expect(invoiceAlreadyPaid(payments, _hex(7)), isFalse);
    });

    test('hash sama tetapi pembayaran KELUAR succeeded → bukan '
        'pelunasan invoice ini', () {
      final payments = [
        _jitPayment(
          hashByte: 7,
          status: PaymentStatus.succeeded,
          direction: PaymentDirection.outbound,
        ),
      ];
      expect(invoiceAlreadyPaid(payments, _hex(7)), isFalse);
    });

    test('pembayaran lunas milik invoice LAIN → invoice ini belum '
        'lunas', () {
      final payments = [
        _jitPayment(hashByte: 8, status: PaymentStatus.succeeded),
        _regularPayment(hashByte: 9, status: PaymentStatus.succeeded),
      ];
      expect(invoiceAlreadyPaid(payments, _hex(7)), isFalse);
    });

    test('catatan kosong → belum lunas', () {
      expect(invoiceAlreadyPaid(const [], _hex(7)), isFalse);
    });

    test('keysend masuk succeeded (bukan pembayaran invoice) → '
        'tidak dihitung', () {
      final payments = [
        PaymentDetails(
          id: PaymentId(data: Uint8List.fromList([7, 7, 7])),
          kind: PaymentKind_Spontaneous(hash: _hash(7)),
          amountMsat: BigInt.from(5000000),
          direction: PaymentDirection.inbound,
          status: PaymentStatus.succeeded,
          latestUpdateTimestamp: BigInt.from(1700000000),
        ),
      ];
      expect(invoiceAlreadyPaid(payments, _hex(7)), isFalse);
    });
  });
}
