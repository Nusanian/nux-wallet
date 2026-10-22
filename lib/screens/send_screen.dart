import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lsp_service.dart';
import '../utils/friendly_error.dart';

/// Layar Kirim — bayar invoice Lightning.
///
/// Alur: tempel/scan invoice → konfirmasi nominal → bayar.
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

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) {
      setState(() => _error = 'Tempel invoice dulu');
      return;
    }
    if (!invoice.startsWith('ln')) {
      setState(() => _error = 'Ini bukan invoice Lightning yang valid');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _paid = false;
    });

    try {
      await widget.lspService.payInvoice(invoice);
      setState(() => _paid = true);
    } catch (e) {
      setState(() => _error =
          friendlyError(e, fallback: 'Pembayaran gagal. Coba lagi.'));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kirim NUX'),
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
                      'Tempel invoice Lightning dari penerima. '
                      'Pembayaran instan via channel.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFB8C8BF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Invoice input
            const Text('Invoice Lightning',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _invoiceController,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'lnnu1... atau lntn1...',
                hintStyle:
                    TextStyle(color: Colors.white.withOpacity(0.2)),
                filled: true,
                fillColor: const Color(0xFF121715),
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
                    label: const Text('Tempel',
                        style: TextStyle(color: Color(0xFF34D399))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: const Color(0xFF34D399).withOpacity(0.3)),
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
                    onPressed: () {
                      // TODO: scan QR pakai package mobile_scanner
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Scan QR — segera hadir')),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner,
                        color: Color(0xFF34D399), size: 18),
                    label: const Text('Scan QR',
                        style: TextStyle(color: Color(0xFF34D399))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: const Color(0xFF34D399).withOpacity(0.3)),
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
              onPressed: _loading ? null : _pay,
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
                  : const Text('Bayar',
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
            if (_paid) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                  ),
                ),
                child: const Column(
                  children: [
                    Text('\u2705',
                        style: TextStyle(fontSize: 40)),
                    SizedBox(height: 8),
                    Text('Pembayaran Berhasil!',
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
