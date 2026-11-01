import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:ldk_node/src/generated/lib.dart';
import 'package:nux_wallet/services/csv_export.dart';

PaymentDetails _bolt11({
  required List<int> idBytes,
  required int hashByte,
  BigInt? amountMsat,
  required PaymentDirection direction,
  required PaymentStatus status,
  int timestamp = 1700000000,
}) {
  return PaymentDetails(
    id: PaymentId(data: Uint8List.fromList(idBytes)),
    kind: PaymentKind_Bolt11(
      hash: PaymentHash(
        data: U8Array32(Uint8List.fromList(List.filled(32, hashByte))),
      ),
    ),
    amountMsat: amountMsat,
    direction: direction,
    status: status,
    latestUpdateTimestamp: BigInt.from(timestamp),
  );
}

void main() {
  group('buildTransactionsCsv', () {
    test('daftar kosong → hanya baris header', () {
      final csv = buildTransactionsCsv(const []);
      expect(csv.trim().split('\n'), hasLength(1));
      expect(csv, startsWith('date_iso,type,direction,status,'));
    });

    test('bolt11 masuk sukses: jumlah pecahan persis, tanda +', () {
      final payment = _bolt11(
        idBytes: [0xab, 0x01],
        hashByte: 7,
        amountMsat: BigInt.from(1500),
        direction: PaymentDirection.inbound,
        status: PaymentStatus.succeeded,
      );
      final lines = buildTransactionsCsv([payment]).trim().split('\n');
      expect(lines, hasLength(2));
      final cells = lines[1].split(',');
      final expectedIso = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000)
          .toIso8601String();
      expect(cells[0], expectedIso);
      expect(cells[1], 'Lightning');
      expect(cells[2], 'Incoming');
      expect(cells[3], 'Succeeded');
      expect(cells[4], '1.5');
      expect(cells[5], '1500');
      expect(cells[6], 'ab01');
      expect(cells[7], List.filled(32, '07').join());
      expect(cells[8], '');
    });

    test('on-chain keluar gagal: tanda -, txid terisi, hash kosong', () {
      final payment = PaymentDetails(
        id: PaymentId(data: Uint8List.fromList([1, 2])),
        kind: PaymentKind_Onchain(
          txid: Txid(hash: 'deadbeef'),
          status: ConfirmationStatus.unconfirmed(),
        ),
        amountMsat: BigInt.from(725000),
        direction: PaymentDirection.outbound,
        status: PaymentStatus.failed,
        latestUpdateTimestamp: BigInt.from(1700000000),
      );
      final cells = buildTransactionsCsv([payment])
          .trim()
          .split('\n')[1]
          .split(',');
      expect(cells[1], 'On-chain');
      expect(cells[2], 'Outgoing');
      expect(cells[3], 'Failed');
      expect(cells[4], '-725');
      expect(cells[5], '-725000');
      expect(cells[7], '');
      expect(cells[8], 'deadbeef');
    });

    test('jumlah kosong dari node → sel jumlah kosong', () {
      final payment = _bolt11(
        idBytes: [9],
        hashByte: 3,
        amountMsat: null,
        direction: PaymentDirection.outbound,
        status: PaymentStatus.pending,
      );
      final cells = buildTransactionsCsv([payment])
          .trim()
          .split('\n')[1]
          .split(',');
      expect(cells[3], 'Pending');
      expect(cells[4], '');
      expect(cells[5], '');
    });
  });
}
