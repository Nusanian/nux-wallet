import 'package:flutter/material.dart';

import '../locale_controller.dart';
import '../services/update_service.dart';
import '../theme.dart';

/// Dialog pembaruan OTA: info versi baru, catatan rilis dwibahasa,
/// unduh + pasang — port dialog OTA nusan-catcher ke gaya ELNUX.
///
/// Dipakai dari cek otomatis diam-diam (Beranda) dan cek manual
/// (tab Profil). Catatan rilis yang ditampilkan mengikuti bahasa
/// aplikasi ([UpdateInfo.catatanUntuk] atas bahasa
/// [LocaleController] aktif).
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  bool _failed = false;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _downloading = true;
      _failed = false;
      _progress = 0;
    });
    final ok = await UpdateService.unduhDanPasang(
      widget.info,
      onProgres: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    if (ok) {
      // Installer sistem sudah dibuka — tutup dialog.
      Navigator.of(context).pop();
    } else {
      setState(() {
        _downloading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = widget.info;
    final notes = info.catatanUntuk(LocaleController.locale.value.languageCode);
    return AlertDialog(
      backgroundColor: context.palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.palette.border),
      ),
      title: Text(
        l10n.updateTitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.updateVersionAvailable(info.versi),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.updateNotes,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: 4),
            // Dibatasi & bisa digulir: catatan panjang tidak boleh
            // mendorong tombol keluar layar kecil (pelajaran
            // nusan-catcher).
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: context.palette.label,
                  ),
                ),
              ),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress <= 0 ? null : _progress.clamp(0.0, 1.0),
              backgroundColor: context.palette.cardAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.updateDownloading((_progress * 100).round()),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.palette.muted),
            ),
          ],
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(
              l10n.updateFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ],
          // Tombol di badan dialog (BUKAN actions: AlertDialog):
          // Material menumpuk actions tanpa jarak vertikal di
          // layar sempit (temuan nusan-catcher) — pola di sini
          // lebar penuh bertumpuk, yang utama di atas. Saat
          // mengunduh tidak ada tombol (dialog modal).
          if (!_downloading) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _downloadAndInstall,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _failed ? l10n.updateRetry : l10n.updateDownloadInstall,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.updateLater,
                style: TextStyle(color: context.palette.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
