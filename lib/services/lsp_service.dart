import 'dart:typed_data';
import 'package:ldk_node/ldk_node.dart';
import 'package:ldk_node/src/generated/api/builder.dart';
import 'package:ldk_node/src/generated/api/node.dart';
import 'package:ldk_node/src/generated/api/bolt11.dart' as bolt11_api;

/// Service untuk koneksi ke LSP Nusacoin via LSPS2 (bLIP-52).
class LspService {
  FfiNode? _node;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> init({
    required List<int> seedBytes,
    required String storagePath,
    required String lspAddress,
    required String lspNodeId,
    String? lspToken,
    required String electrumUrl,
    bool isTestnet = true,
  }) async {
    final parts = lspAddress.split(':');
    final lspPort = int.parse(parts[1]);
    final octets = Uint8List.fromList(
        parts[0].split('.').map(int.parse).toList());

    final config = Config(
      network: isTestnet ? Network.testnet : Network.nusacoin,
      storageDirPath: storagePath,
      trustedPeers0Conf: [PublicKey(hex: lspNodeId)],
      probingLiquidityLimitMultiplier: BigInt.from(3),
    );

    final chainConfig = ChainDataSourceConfig.electrum(
      serverUrl: electrumUrl,
    );

    final liquidityConfig = LiquiditySourceConfig(
      lsps2Service: (
        SocketAddress.tcpIpV4(
          addr: U8Array4(octets),
          port: lspPort,
        ),
        PublicKey(hex: lspNodeId),
        lspToken,
      ),
    );

    final builder = FfiBuilder.createBuilder(
      config: config,
      chainDataSourceConfig: chainConfig,
      liquiditySourceConfig: liquidityConfig,
    );

    builder.setEntropySeedBytes(seedBytes: seedBytes);

    _node = await builder.build();
    await _node!.start();
    _running = true;
  }

  Future<String> createJitInvoice({
    required BigInt amountMsat,
    required String description,
    int expirySecs = 3600,
  }) async {
    _ensureRunning();
    final payment = await FfiNode.bolt11Payment(ptr: _node!);
    final invoice = await payment.receiveViaJitChannelUnsafe(
      amountMsat: amountMsat,
      description: description,
      expirySecs: expirySecs,
    );
    return invoice.signedRawInvoice;
  }

  Future<void> payInvoice(String invoiceStr) async {
    _ensureRunning();
    final payment = await FfiNode.bolt11Payment(ptr: _node!);
    final invoice = Bolt11Invoice(signedRawInvoice: invoiceStr);
    await payment.send(invoice: invoice);
  }

  Future<BigInt> getLightningBalance() async {
    _ensureRunning();
    final balances = await _node!.listBalances();
    // totalLightningBalanceSats dalam sats, konversi ke msat
    return balances.totalLightningBalanceSats * BigInt.from(1000);
  }

  Future<void> stop() async {
    if (_running && _node != null) {
      await _node!.stop();
      _running = false;
      _node = null;
    }
  }

  void _ensureRunning() {
    if (!_running || _node == null) {
      throw StateError('Node belum diinisialisasi. Panggil init() dulu.');
    }
  }
}
