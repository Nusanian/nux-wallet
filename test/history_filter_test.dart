import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:ldk_node/src/generated/lib.dart';
import 'package:nux_wallet/services/history_filter.dart';

PaymentDetails _paymentAt(int idByte, DateTime time) {
  return PaymentDetails(
    id: PaymentId(data: Uint8List.fromList([idByte])),
    kind: PaymentKind_Bolt11(
      hash: PaymentHash(
        data: U8Array32(Uint8List.fromList(List.filled(32, idByte))),
      ),
    ),
    amountMsat: BigInt.from(1000),
    direction: PaymentDirection.inbound,
    status: PaymentStatus.succeeded,
    latestUpdateTimestamp: BigInt.from(time.millisecondsSinceEpoch ~/ 1000),
  );
}

void main() {
  // Senin 2 Nov 2026 pukul 12.00 waktu setempat.
  final now = DateTime(2026, 11, 2, 12);

  group('historyRangeForPreset + filterPaymentsByRange', () {
    test('bawaan 7 hari: jendela bergulir, batas awal inklusif', () {
      final range = historyRangeForPreset(
        HistoryRangePreset.last7Days,
        now: now,
      );
      final payments = [
        _paymentAt(1, now.subtract(const Duration(days: 3))),
        _paymentAt(2, now.subtract(const Duration(days: 7))),
        _paymentAt(3, now.subtract(const Duration(days: 7, seconds: 1))),
        _paymentAt(4, now.subtract(const Duration(days: 29))),
      ];
      final result = filterPaymentsByRange(payments, range);
      expect(result.map((p) => p.id.data[0]), [1, 2]);
    });

    test('30 hari: pembayaran umur 29 hari masuk, 31 hari tidak', () {
      final range = historyRangeForPreset(
        HistoryRangePreset.last30Days,
        now: now,
      );
      final payments = [
        _paymentAt(1, now.subtract(const Duration(days: 29))),
        _paymentAt(2, now.subtract(const Duration(days: 31))),
      ];
      final result = filterPaymentsByRange(payments, range);
      expect(result.map((p) => p.id.data[0]), [1]);
    });

    test('custom: hari kalender utuh, tanggal akhir tercakup penuh', () {
      final range = historyRangeForPreset(
        HistoryRangePreset.custom,
        now: now,
        customStart: DateTime(2026, 10, 10),
        customEnd: DateTime(2026, 10, 12),
      );
      final payments = [
        _paymentAt(1, DateTime(2026, 10, 9, 23, 59)),
        _paymentAt(2, DateTime(2026, 10, 10)),
        _paymentAt(3, DateTime(2026, 10, 12, 23, 59)),
        _paymentAt(4, DateTime(2026, 10, 13)),
      ];
      final result = filterPaymentsByRange(payments, range);
      expect(result.map((p) => p.id.data[0]), [2, 3]);
    });

    test('daftar kosong tetap kosong; urutan masukan dipertahankan', () {
      final range = historyRangeForPreset(
        HistoryRangePreset.last7Days,
        now: now,
      );
      expect(filterPaymentsByRange(const [], range), isEmpty);
      final payments = [
        _paymentAt(9, now.subtract(const Duration(days: 1))),
        _paymentAt(8, now.subtract(const Duration(days: 2))),
      ];
      expect(filterPaymentsByRange(payments, range).map((p) => p.id.data[0]), [
        9,
        8,
      ]);
    });
  });
}
