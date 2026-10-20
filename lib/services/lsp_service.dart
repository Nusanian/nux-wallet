import 'dart:io';

import 'package:ldk_node/ldk_node.dart';
import 'package:ldk_node/src/generated/api/builder.dart';
import 'package:ldk_node/src/generated/api/node.dart';
import 'package:ldk_node/src/generated/api/bolt11.dart' as bolt11_api;
import 'package:ldk_node/src/utils/frb.dart';

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
    // Inisialisasi runtime flutter_rust_bridge (kelas `core` di
    // binding) sebelum panggilan API pertama. verifyInit idempotent:
    // aman dipanggil ulang saat retry. Tanpa ini aplikasi berhenti
    // dengan StateError "flutter_rust_bridge has not been initialized".
    await Frb.verifyInit();
    // lspAddress format "host:port" — host boleh hostname (mis.
    // lsp.taobot.org) atau IPv4 dotted. Hostname di-resolve ke IPv4 dulu
    // supaya memakai jalur SocketAddress.tcpIpV4 yang sudah terbukti di
    // uji handshake LSPS2 19 Okt 2026.
    final sep = lspAddress.lastIndexOf(':');
    if (sep < 0) {
      throw StateError(
          'Format lspAddress salah: "$lspAddress" (mesti host:port)');
    }
    final lspHost = lspAddress.substring(0, sep);
    final lspPort = int.parse(lspAddress.substring(sep + 1));
    final addrs = await InternetAddress.lookup(lspHost);
    final ipv4 = addrs.firstWhere(
      (a) => a.type == InternetAddressType.IPv4,
      orElse: () =>
          throw StateError('Tidak ada alamat IPv4 untuk host "$lspHost"'),
    );

    final config = Config(
      // Testnet = Nusacoin testnet (X11) — chain hash-nya cocok dengan
      // server LSP. JANGAN pakai Network.testnet: itu Bitcoin testnet3,
      // chain hash-nya beda sehingga handshake P2P dengan LSP ditolak
      // dan sync header dari electrs gagal.
      network: isTestnet ? Network.nusacoinTestnet : Network.nusacoin,
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
          addr: U8Array4(ipv4.rawAddress),
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

    // setEntropySeedBytes MEMAKAN builder (parameter `self` di Rust)
    // dan mengembalikan builder baru — nilai kembalinya WAJIB yang
    // dipakai. Memanggil build() pada builder lama melempar
    // DroppableDisposedException (RustArc sudah di-dispose).
    final configuredBuilder =
        builder.setEntropySeedBytes(seedBytes: seedBytes);

    _node = await configuredBuilder.build();
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
