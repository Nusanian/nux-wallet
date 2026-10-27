import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale_controller.dart';
import '../theme.dart';
import '../utils/friendly_error.dart';

/// Layar Restore Phrase — pulihkan dompet dari frasa backup BIP39.
///
/// Alur: ketik/tempel frasa → validasi lokal (jumlah kata + checksum
/// BIP39) → dialog konfirmasi penghapusan dompet aktif → [onRestore]
/// mengeksekusi (hentikan node, hapus berkas dompet aktif, tulis
/// seed turunan frasa, boot ulang). Layar ini TIDAK menyentuh berkas
/// dompet sendiri; semua efek samping milik pemanggil.
class RestoreScreen extends StatefulWidget {
  /// Dipanggil dengan frasa yang sudah tervalidasi. Melempar bila
  /// restore gagal; layar menampilkan errornya.
  final Future<void> Function(String mnemonic) onRestore;

  const RestoreScreen({super.key, required this.onRestore});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final _phraseController = TextEditingController();
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  /// Normalisasi input user: huruf kecil, koma/baris baru jadi spasi,
  /// spasi ganda diciutkan. Frasa BIP39 ELNUX berbahasa Inggris.
  List<String> get _words {
    final text = _phraseController.text
        .toLowerCase()
        .replaceAll(RegExp(r'[,;\n\r]+'), ' ');
    return text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Validasi lokal sebelum konfirmasi: jumlah kata BIP39 yang sah,
  /// lalu kata + checksum lewat package bip39 yang sama dengan _boot.
  String? _validate() {
    final words = _words;
    if (![12, 15, 18, 21, 24].contains(words.length)) {
      return context.l10n.restoreInvalidCount;
    }
    if (!bip39.validateMnemonic(words.join(' '))) {
      return context.l10n.restoreInvalidWords;
    }
    return null;
  }

  Future<void> _restore() async {
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    // Peringatan keras: restore MENIMPA dompet aktif permanen.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ctx.palette.border),
        ),
        title: Text(ctx.l10n.restoreConfirmTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          ctx.l10n.restoreConfirmBody,
          style:
              TextStyle(fontSize: 13.5, color: ctx.palette.secondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel,
                style: TextStyle(color: ctx.palette.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.restoreConfirmAction,
                style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.onRestore(_words.join(' '));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e,
              fallback: context.l10n.restoreFailed, l10n: context.l10n);
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.restoreWallet),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Penjelasan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                context.l10n.restoreIntro,
                style:
                    TextStyle(fontSize: 13, color: context.palette.label, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            // Input frasa
            TextField(
              controller: _phraseController,
              maxLines: 5,
              minLines: 3,
              enabled: !_working,
              onChanged: (_) => setState(() => _error = null),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: context.l10n.restoreHint,
                hintStyle: TextStyle(color: context.palette.hint),
                filled: true,
                fillColor: context.palette.cardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  context.l10n.restoreWordCount(_words.length),
                  style:
                      TextStyle(fontSize: 12, color: context.palette.muted),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            _phraseController.text = data!.text!;
                            setState(() => _error = null);
                          }
                        },
                  icon: const Icon(Icons.paste,
                      color: Color(0xFF34D399), size: 16),
                  label: Text(context.l10n.paste,
                      style: const TextStyle(color: Color(0xFF34D399))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: const Color(0xFF34D399).withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Tombol pulihkan
            ElevatedButton(
              onPressed: _working ? null : _restore,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _working
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(context.l10n.restoreButton,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (_working) ...[
              const SizedBox(height: 12),
              Text(context.l10n.restoreWorking,
                  style:
                      TextStyle(fontSize: 13, color: context.palette.secondary),
                  textAlign: TextAlign.center),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
