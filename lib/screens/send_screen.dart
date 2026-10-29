import 'package:flutter/material.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:vibration/vibration.dart';
import '../config.dart';
import '../locale_controller.dart';
import '../theme.dart';
import 'package:flutter/services.dart';
import '../services/lsp_service.dart';
import '../utils/animated_checkmark.dart';
import '../utils/friendly_error.dart';
import 'scan_screen.dart';

/// Normalisasi hasil scan QR menjadi teks invoice siap pakai:
/// buang awalan "lightning:" (beberapa QR memakainya), dan samakan
/// huruf menjadi kecil — invoice bech32 sah dalam huruf besar semua,
/// diseragamkan agar lolos pemeriksaan awalan di layar Kirim.
String normalizeInvoice(String raw) {
  var text = raw.trim();
  if (text.toLowerCase().startsWith('lightning:')) {
    text = text.substring('lightning:'.length).trim();
  }
  if (text.toLowerCase().startsWith('ln')) {
    text = text.toLowerCase();
  }
  return text;
}

/// Layar Kirim — bayar invoice Lightning.
///
/// Alur: tempel/scan invoice → konfirmasi (dialog + getar) → bayar →
/// TUNGGU hasil akhir. Tombol Bayar TIDAK langsung membayar: user
/// harus menekan Bayar sekali lagi di dialog konfirmasi. Ini
/// sengaja, karena pembayaran Lightning bersifat instan dan tidak
/// bisa dibatalkan — ketukan Bayar yang tidak sengaja sebelumnya
/// langsung mengirim dana.
///
/// Centang berhasil hanya tampil setelah pembayaran benar-benar
/// berstatus sukses di catatan node (lihat
/// LspService.waitForPaymentOutcome): perintah kirim yang diterima
/// node bukan bukti pembayaran sampai — pembayaran bisa gagal di
/// jalan, misalnya penerima sedang tidak terhubung. Bila hasil
/// akhir tidak kunjung jelas sampai batas tunggu, layar menyatakan
/// "masih diproses" apa adanya dan mengarahkan ke Riwayat, bukan
/// mengklaim sukses atau gagal.
class SendScreen extends StatefulWidget {
  final LspService lspService;

  const SendScreen({super.key, required this.lspService});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _invoiceController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _paid = false;

  /// True selama perintah kirim sudah diterima node dan aplikasi
  /// sedang menunggu status final pembayaran.
  bool _waitingOutcome = false;

  /// True bila batas tunggu habis dan status masih pending:
  /// pembayaran belum jelas hasil akhirnya (bukan sukses, bukan
  /// gagal) — user diarahkan memeriksa Riwayat dan dilarang
  /// membayar ulang invoice yang sama.
  bool _stillPending = false;

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  /// Getar singkat saat dialog konfirmasi muncul — penanda fisik
  /// bahwa ketukan Bayar belum mengirim apa-apa, masih bisa dibatalkan.
  /// Kegagalan getar (perangkat tanpa vibrator, izin, dll.) ditelan
  /// diam-diam, sama seperti CoinAlert: tidak boleh mengganggu alur.
  Future<void> _vibrateConfirm() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 150);
      }
    } catch (_) {
      // Tanpa getar pun konfirmasi tetap jalan.
    }
  }

  /// Potongan invoice untuk dialog konfirmasi: cukup untuk
  /// membedakan invoice ini dari invoice lain, tanpa memenuhi dialog.
  String _invoicePreview(String invoice) {
    if (invoice.length <= 40) return invoice;
    return '${invoice.substring(0, 24)}…${invoice.substring(invoice.length - 12)}';
  }

  /// Ketukan Bayar pertama: validasi, getar, lalu minta konfirmasi.
  /// Pembayaran baru jalan bila user menekan Bayar di dialog.
  Future<void> _onPayPressed() async {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) {
      setState(() => _error = context.l10n.pasteInvoiceFirst);
      return;
    }
    if (!invoice.startsWith('ln')) {
      setState(() => _error = context.l10n.invalidInvoice);
      return;
    }
    await _vibrateConfirm();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.confirmPayTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.confirmPayBody),
            const SizedBox(height: 12),
            Text(
              _invoicePreview(invoice),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.pay),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _pay();
    }
  }

  Future<void> _pay() async {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) {
      setState(() => _error = context.l10n.pasteInvoiceFirst);
      return;
    }
    if (!invoice.startsWith('ln')) {
      setState(() => _error = context.l10n.invalidInvoice);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _paid = false;
      _stillPending = false;
      _waitingOutcome = false;
    });

    try {
      final paymentId = await widget.lspService.payInvoice(invoice);
      if (!mounted) return;
      // Perintah kirim diterima node — mulai tunggu hasil AKHIR.
      // Tanpa penungguan ini centang berhasil tampil prematur dan
      // kegagalan susulan (mis. penerima offline) tidak pernah
      // diperlihatkan ke pengirim.
      setState(() => _waitingOutcome = true);
      final outcome =
          await widget.lspService.waitForPaymentOutcome(paymentId);
      if (!mounted) return;
      if (outcome == PaymentStatus.succeeded) {
        setState(() => _paid = true);
      } else if (outcome == PaymentStatus.failed) {
        setState(() => _error = context.l10n.payFailedFinal);
      } else {
        // Lewat batas tunggu dan masih pending: nyatakan apa
        // adanya, jangan klaim sukses maupun gagal.
        setState(() => _stillPending = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e,
          fallback: context.l10n.payFailed, l10n: context.l10n));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _waitingOutcome = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sendTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Text('\u26A1', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.sendInfo,
                      style: TextStyle(fontSize: 13, color: context.palette.label),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Invoice input
            Text(context.l10n.invoiceTitle,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _invoiceController,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                // Hint hanya menampilkan SATU format: prefix HRP jaringan
                // yang sedang dipakai (lntn di testnet, lnnu di mainnet).
                // Sebelumnya hardcode 'lnnu1... atau lntn1...' sehingga
                // user mainnet melihat format testnet dan bingung.
                // Diambil dari AppConfig.isTestnet (sudah benar per branch
                // lewat config kulit masing-masing) — tanpa mengubah
                // config.dart, jadi sync ke mainnet aman.
                hintText: AppConfig.isTestnet ? 'lntn1...' : 'lnnu1...',
                hintStyle:
                    TextStyle(color: context.palette.hint),
                filled: true,
                fillColor: context.palette.cardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final data =
                          await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _invoiceController.text = data!.text!;
                      }
                    },
                    icon: const Icon(Icons.paste,
                        color: Color(0xFF34D399), size: 18),
                    label: Text(context.l10n.paste,
                        style: TextStyle(color: Color(0xFF34D399))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: const Color(0xFF34D399).withValues(alpha: 0.3)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final scanned = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanScreen(),
                        ),
                      );
                      if (!mounted) return;
                      if (scanned != null) {
                        _invoiceController.text =
                            normalizeInvoice(scanned);
                        setState(() => _error = null);
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner,
                        color: Color(0xFF34D399), size: 18),
                    label: Text(context.l10n.scanQr,
                        style: TextStyle(color: Color(0xFF34D399))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: const Color(0xFF34D399).withValues(alpha: 0.3)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Pay button
            ElevatedButton(
              onPressed: _loading ? null : _onPayPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(context.l10n.pay,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
            if (_waitingOutcome) ...[
              const SizedBox(height: 12),
              Text(context.l10n.payWaitingOutcome,
                  style:
                      TextStyle(fontSize: 13, color: context.palette.muted),
                  textAlign: TextAlign.center),
            ],
            if (_stillPending) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  context.l10n.payStillPending,
                  style: TextStyle(
                      fontSize: 13, color: context.palette.label),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (_paid) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    const AnimatedCheckmark(),
                    SizedBox(height: 8),
                    Text(context.l10n.paymentSuccess,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF34D399))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
