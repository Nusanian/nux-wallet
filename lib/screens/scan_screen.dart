import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../locale_controller.dart';

/// Layar Scan QR — membaca QR invoice Lightning dengan kamera
/// atau dari gambar QR yang tersimpan di galeri.
///
/// Mengembalikan teks hasil scan (String) ke pemanggil lewat
/// Navigator.pop, atau null bila user membatalkan.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      _handled = true;
      Navigator.pop(context, raw.trim());
      return;
    }
  }

  /// Memilih gambar QR dari galeri dan mendekodenya dengan mesin
  /// yang sama seperti pindaian kamera (analyzeImage). Hasil yang
  /// valid diteruskan ke [_onDetect]; gambar yang tidak memuat QR
  /// yang terbaca diberi tahu lewat snackbar.
  Future<void> _pickFromGallery() async {
    if (_handled) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(picked.path);
    } catch (_) {
      capture = null;
    }
    if (!mounted) return;
    if (capture == null ||
        !capture.barcodes.any(
          (b) => b.rawValue != null && b.rawValue!.trim().isNotEmpty,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.scanNoQrFound)),
      );
      return;
    }
    _onDetect(capture);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.scanTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: context.l10n.scanFromGallery,
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    error.errorCode ==
                            MobileScannerErrorCode.permissionDenied
                        ? context.l10n.cameraDenied
                        : context.l10n.cameraUnavailable,
                    style: const TextStyle(
                        color: Color(0xFFB8C8BF), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          // Bingkai bidik + petunjuk di atas pratinjau kamera.
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: const Color(0xFF34D399), width: 2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.pointCamera,
                    style: TextStyle(color: Colors.white70, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
