import 'dart:io';

import 'package:ldk_node/ldk_node.dart';
import 'package:ldk_node/src/generated/api/builder.dart';
import 'package:ldk_node/src/generated/api/node.dart';
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

  /// Kirim pembayaran invoice dan kembalikan ID pembayaran-nya.
  ///
  /// PERHATIAN: kembalian send() hanya berarti perintah kirim
  /// DITERIMA node — pembayaran belum tentu sampai. Hasil akhir
  /// (sukses/gagal) baru diketahui belakangan di catatan pembayaran;
  /// pantau lewat [waitForPaymentOutcome]. Menampilkan "berhasil"
  /// hanya dari send() adalah centang prematur.
  Future<PaymentId> payInvoice(String invoiceStr) async {
    _ensureRunning();
    final payment = await FfiNode.bolt11Payment(ptr: _node!);
    final invoice = Bolt11Invoice(signedRawInvoice: invoiceStr);
    return await payment.send(invoice: invoice);
  }

  /// Tunggu hasil akhir pembayaran [paymentId] dengan memeriksa
  /// catatan pembayaran node berkala.
  ///
  /// Mengembalikan status final (succeeded/failed) begitu terlihat,
  /// atau null bila sampai [timeout] statusnya masih pending —
  /// null BUKAN berarti gagal: pembayaran masih berjalan dan hasil
  /// akhirnya akan muncul di Riwayat. Polling catatan pembayaran
  /// (bukan antrean event) dipilih supaya tidak merebut event yang
  /// dibutuhkan layar Terima.
  Future<PaymentStatus?> waitForPaymentOutcome(
    PaymentId paymentId, {
    Duration timeout = const Duration(seconds: 60),
    Duration interval = const Duration(seconds: 2),
  }) async {
    _ensureRunning();
    final idHex = paymentIdHex(paymentId);
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final payments = await listPayments();
      final status = findPaymentStatus(payments, idHex);
      if (status != null && status != PaymentStatus.pending) return status;
      if (!DateTime.now().add(interval).isBefore(deadline)) return null;
      await Future<void>.delayed(interval);
    }
  }

  Future<BigInt> getLightningBalance() async {
    _ensureRunning();
    final balances = await _node!.listBalances();
    // totalLightningBalanceSats dalam sats, konversi ke msat
    return balances.totalLightningBalanceSats * BigInt.from(1000);
  }

  /// Ambil seluruh riwayat pembayaran dari node, terbaru di depan.
  ///
  /// Binding tidak menjamin urutan, jadi hasil diurutkan menurun
  /// menurut latestUpdateTimestamp. Semua status ikut terbawa
  /// (termasuk menunggu/gagal) dan semua jenis pembayaran
  /// (Lightning + on-chain) — penyaringan tampilan urusan UI.
  Future<List<PaymentDetails>> listPayments() async {
    _ensureRunning();
    final payments = await _node!.listPayments();
    payments.sort((a, b) =>
        b.latestUpdateTimestamp.compareTo(a.latestUpdateTimestamp));
    return payments;
  }

  /// Ambil satu event node dari antrean (non-blocking).
  ///
  /// Mengembalikan null bila antrean kosong. Dipakai layar Terima
  /// untuk menunggu event pembayaran masuk (Event.paymentReceived).
  ///
  /// Catatan: nextEvent() hanya mengintip (peek) — event yang sama akan
  /// terus dikembalikan sampai ditandai selesai lewat eventHandled().
  /// Karena itu setiap event yang terbaca langsung ditandai selesai di
  /// sini, supaya event berikutnya (mis. PaymentReceived) bisa maju.
  Future<Event?> pollNextEvent() async {
    _ensureRunning();
    final event = await _node!.nextEvent();
    if (event != null) {
      await _node!.eventHandled();
    }
    return event;
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

/// Bentuk hex ID pembayaran. Pencocokan pembayaran antar-panggilan
/// memakai hex ini, bukan equality objek PaymentId, supaya tidak
/// bergantung pada identitas objek data di binding.
String paymentIdHex(PaymentId id) =>
    id.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Status pembayaran ber-ID [idHex] dalam daftar [payments];
/// null bila catatannya belum muncul.
PaymentStatus? findPaymentStatus(
    List<PaymentDetails> payments, String idHex) {
  for (final p in payments) {
    if (paymentIdHex(p.id) == idHex) return p.status;
  }
  return null;
}
