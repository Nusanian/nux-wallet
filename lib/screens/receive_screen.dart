import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/lsp_service.dart';
import '../utils/format.dart';

/// Layar Terima — buat invoice Lightning via JIT channel.
///
/// Alur: user isi nominal → tekan Buat Invoice → QR + invoice muncul →
/// pembayar scan → LSP buka channel 0-conf → dana masuk.
class ReceiveScreen extends StatefulWidget {
  final LspService lspService;

  const ReceiveScreen({super.key, required this.lspService});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _amountController = TextEditingController();
  String? _invoice;
  bool _loading = false;
  String? _error;

  /// Pengawasan event pembayaran masuk untuk invoice aktif.
  Timer? _eventTimer;
  int _watchGen = 0;
  bool _received = false;
  BigInt? _receivedMsat;

  @override
  void dispose() {
    _eventTimer?.cancel();
    _watchGen++;
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    final text = _amountController.text.trim();
    final nusan = double.tryParse(text);
    if (nusan == null || nusan <= 0) {
      setState(() => _error = 'Masukkan nominal yang valid');
      return;
    }

    _eventTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _invoice = null;
      _received = false;
      _receivedMsat = null;
    });

    try {
      // 1 nusan = 1000 msat
      final amountMsat = BigInt.from((nusan * 1000).round());
      final invoice = await widget.lspService.createJitInvoice(
        amountMsat: amountMsat,
        description: 'Terima $nusan nusan',
      );
      setState(() => _invoice = invoice);
      _startWatching();
    } catch (e) {
      setState(() => _error = 'Gagal buat invoice: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Tunggu pembayaran invoice ini lewat antrean event node
  /// (Event.paymentReceived dari binding LDK).
  ///
  /// Antrean event lebih dulu dikuras: event adalah antrean bersama
  /// satu node, jadi PaymentReceived milik pembayaran lama yang belum
  /// sempat dibaca tidak boleh memicu status sukses palsu di sini.
  Future<void> _startWatching() async {
    _eventTimer?.cancel();
    final gen = ++_watchGen;
    await _drainEvents();
    if (!mounted || gen != _watchGen) return;
    _eventTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollEvents(gen),
    );
  }

  Future<void> _drainEvents() async {
    try {
      for (var i = 0; i < 100; i++) {
        final e = await widget.lspService.pollNextEvent();
        if (e == null) break;
      }
    } catch (_) {
      // Node belum siap — abaikan, polling berikutnya yang bekerja.
    }
  }

  Future<void> _pollEvents(int gen) async {
    if (!mounted || gen != _watchGen || _received) return;
    try {
      // Sekali tick, baca sampai 20 event: pembukaan channel JIT
      // menghasilkan beberapa event sebelum PaymentReceived.
      for (var i = 0; i < 20; i++) {
        final e = await widget.lspService.pollNextEvent();
        if (e == null) break;
        if (e is Event_PaymentReceived) {
          _eventTimer?.cancel();
          if (mounted && gen == _watchGen) {
            setState(() {
              _received = true;
              _receivedMsat = e.amountMsat;
            });
          }
          return;
        }
      }
    } catch (_) {
      // Gagal baca sesaat — coba lagi di tick berikut.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terima NUX'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info JIT
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: const Row(
                children: [
                  Text('\u26A1', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Invoice Lightning dengan channel instan (JIT). '
                      'Tidak perlu tunggu konfirmasi block.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFB8C8BF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Amount input
            const Text('Nominal (nusan)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.2)),
                filled: true,
                fillColor: const Color(0xFF121715),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                suffixText: 'nusan',
                suffixStyle: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF7D8F86),
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            // Create button
            ElevatedButton(
              onPressed: _loading ? null : _createInvoice,
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
                  : const Text('Buat Invoice',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            if (_received) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0x2610B981),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0x6610B981),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 72, color: Color(0xFF34D399)),
                    const SizedBox(height: 12),
                    const Text('Pembayaran Diterima',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF34D399))),
                    const SizedBox(height: 6),
                    Text(
                        '+${formatNusan(_receivedMsat ?? BigInt.zero)} nusan',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'Dana sudah masuk ke channel Lightning kamu.',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF7D8F86)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (_invoice != null) ...[
              const SizedBox(height: 24),
              const Text('Invoice Lightning',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: QrImageView(
                    data: _invoice!,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF121715),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _invoice!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFB8C8BF)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          color: Color(0xFF34D399)),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _invoice!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Invoice disalin')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bagikan invoice ini ke pengirim. '
                'Channel akan dibuka otomatis saat pembayaran diterima.',
                style:
                    TextStyle(fontSize: 12, color: Color(0xFF7D8F86)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
