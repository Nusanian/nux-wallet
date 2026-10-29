import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:ldk_node/src/generated/lib.dart';
import 'package:nux_wallet/services/lsp_service.dart';

PaymentDetails _payment(List<int> idBytes, PaymentStatus status) {
  return PaymentDetails(
    id: PaymentId(data: Uint8List.fromList(idBytes)),
    kind: PaymentKind_Spontaneous(
      hash: PaymentHash(
          data: U8Array32(Uint8List.fromList(List.filled(32, 7)))),
    ),
    amountMsat: BigInt.from(5000000),
    direction: PaymentDirection.outbound,
    status: status,
    latestUpdateTimestamp: BigInt.from(1700000000),
  );
}

void main() {
  group('paymentIdHex + findPaymentStatus', () {
    test('hex dari byte ID pembayaran', () {
      final id = PaymentId(data: Uint8List.fromList([0xab, 0x01, 0xff]));
      expect(paymentIdHex(id), 'ab01ff');
    });

    test('status ditemukan berdasarkan ID yang cocok', () {
      final payments = [
        _payment([1, 2, 3], PaymentStatus.succeeded),
        _payment([4, 5, 6], PaymentStatus.pending),
        _payment([7, 8, 9], PaymentStatus.failed),
      ];
      expect(findPaymentStatus(payments, '040506'), PaymentStatus.pending);
      expect(findPaymentStatus(payments, '070809'), PaymentStatus.failed);
      expect(findPaymentStatus(payments, '010203'), PaymentStatus.succeeded);
    });

    test('ID tidak ada di daftar → null (belum tercatat)', () {
      final payments = [_payment([1], PaymentStatus.succeeded)];
      expect(findPaymentStatus(payments, 'beef'), isNull);
      expect(findPaymentStatus(const [], '0102'), isNull);
    });
  });
}
