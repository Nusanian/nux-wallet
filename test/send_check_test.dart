import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:ldk_node/src/generated/lib.dart';
import 'package:nux_wallet/services/lsp_service.dart';

ChannelDetails _channel({required bool usable, required int outboundMsat}) {
  return ChannelDetails(
    channelId: ChannelId(
        data: U8Array32(Uint8List.fromList(List.filled(32, 1)))),
    counterpartyNodeId: PublicKey(hex: '02${'11' * 32}'),
    channelValueSats: BigInt.from(25000),
    userChannelId:
        UserChannelId(data: Uint8List.fromList(List.filled(16, 0))),
    feerateSatPer1000Weight: 1000,
    outboundCapacityMsat: BigInt.from(outboundMsat),
    inboundCapacityMsat: BigInt.zero,
    isOutbound: false,
    isChannelReady: usable,
    isUsable: usable,
    counterpartyUnspendablePunishmentReserve: BigInt.from(1000),
    nextOutboundHtlcLimitMsat: BigInt.zero,
    nextOutboundHtlcMinimumMsat: BigInt.zero,
    inboundHtlcMinimumMsat: BigInt.from(1000),
    config: ChannelConfig(
      forwardingFeeProportionalMillionths: 0,
      forwardingFeeBaseMsat: 0,
      cltvExpiryDelta: 72,
      maxDustHtlcExposure:
          MaxDustHTLCExposure_FeeRateMultiplier(BigInt.from(1000)),
      forceCloseAvoidanceMaxFeeSatoshis: BigInt.from(1000),
      acceptUnderpayingHtlcs: false,
    ),
  );
}

void main() {
  group('totalUsableOutboundCapacityMsat', () {
    test('tanpa channel: nol', () {
      expect(totalUsableOutboundCapacityMsat([]), BigInt.zero);
    });

    test('hanya channel usable yang dijumlahkan', () {
      final channels = [
        _channel(usable: true, outboundMsat: 657000),
        _channel(usable: false, outboundMsat: 9000000),
      ];
      expect(totalUsableOutboundCapacityMsat(channels),
          BigInt.from(657000));
    });

    test('beberapa channel usable dijumlahkan', () {
      final channels = [
        _channel(usable: true, outboundMsat: 1000000),
        _channel(usable: true, outboundMsat: 2500000),
        _channel(usable: false, outboundMsat: 4000000),
      ];
      expect(totalUsableOutboundCapacityMsat(channels),
          BigInt.from(3500000));
    });
  });

  group('evaluateSend', () {
    // Satuan msat. Patokan kasus lapangan 31 Okt: saldo 995 nusan
    // (995.000 msat), kapasitas kirim 0 karena cadangan 1.000 nusan
    // pada channel 25.000.
    test('kasus lapangan: saldo 995, kirim 500 → tertahan cadangan', () {
      expect(
        evaluateSend(
          amountMsat: BigInt.from(500000),
          balanceMsat: BigInt.from(995000),
          usableOutboundMsat: BigInt.zero,
          hasUsableChannel: true,
        ),
        SendCheck.reserveHeld,
      );
    });

    test('saldo bertambah melewati cadangan: kirim yang sama → ok', () {
      // Sesudah terima 662: saldo 1.657, kapasitas kirim 657 —
      // pembayaran 500 yang tadinya gagal memang lolos di lapangan.
      expect(
        evaluateSend(
          amountMsat: BigInt.from(500000),
          balanceMsat: BigInt.from(1657000),
          usableOutboundMsat: BigInt.from(657000),
          hasUsableChannel: true,
        ),
        SendCheck.ok,
      );
    });

    test('nominal persis sebesar kapasitas kirim → ok', () {
      expect(
        evaluateSend(
          amountMsat: BigInt.from(657000),
          balanceMsat: BigInt.from(1657000),
          usableOutboundMsat: BigInt.from(657000),
          hasUsableChannel: true,
        ),
        SendCheck.ok,
      );
    });

    test('nominal melewati saldo → saldo tidak cukup', () {
      expect(
        evaluateSend(
          amountMsat: BigInt.from(2000000),
          balanceMsat: BigInt.from(1657000),
          usableOutboundMsat: BigInt.from(657000),
          hasUsableChannel: true,
        ),
        SendCheck.insufficientBalance,
      );
    });

    test('di atas saldo DAN di atas kapasitas: saldo didahulukan', () {
      expect(
        evaluateSend(
          amountMsat: BigInt.from(9000000),
          balanceMsat: BigInt.from(995000),
          usableOutboundMsat: BigInt.zero,
          hasUsableChannel: true,
        ),
        SendCheck.insufficientBalance,
      );
    });

    test('tanpa channel usable: pemeriksaan cadangan dilewati', () {
      expect(
        evaluateSend(
          amountMsat: BigInt.from(500000),
          balanceMsat: BigInt.from(995000),
          usableOutboundMsat: BigInt.zero,
          hasUsableChannel: false,
        ),
        SendCheck.ok,
      );
    });

    test('tanpa channel usable pun saldo tetap diperiksa', () {
      expect(
        evaluateSend(
          amountMsat: BigInt.from(2000000),
          balanceMsat: BigInt.from(995000),
          usableOutboundMsat: BigInt.zero,
          hasUsableChannel: false,
        ),
        SendCheck.insufficientBalance,
      );
    });
  });
}
