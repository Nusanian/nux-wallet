import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Layar Backup Phrase — WAJIB untuk self-custodial.
///
/// Kunci di HP user. Hilang = dana hilang permanen.
/// Ditampilkan sekali saat pertama kali buat wallet.
class BackupScreen extends StatefulWidget {
  final List<String> mnemonic;

  const BackupScreen({super.key, required this.mnemonic});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _revealed = false;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Wallet'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: const Row(
                children: [
                  Text('\u26A0\uFE0F', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tulis kata-kata ini di kertas dan simpan di tempat aman. '
                      'Siapa pun yang punya kata-kata ini bisa mengambil danamu.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFB8C8BF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!_revealed) ...[
              ElevatedButton(
                onPressed: () => setState(() => _revealed = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Tampilkan Kata Backup',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ] else ...[
              // Word grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: widget.mnemonic.length,
                itemBuilder: (context, i) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121715),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${i + 1}.',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7D8F86))),
                          const SizedBox(width: 4),
                          Text(widget.mnemonic[i],
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: widget.mnemonic.join(' ')));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Kata backup disalin')),
                  );
                },
                icon: const Icon(Icons.copy,
                    color: Color(0xFF34D399)),
                label: const Text('Salin',
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
              const SizedBox(height: 20),
              // Confirmation checkbox
              CheckboxListTile(
                value: _confirmed,
                onChanged: (v) =>
                    setState(() => _confirmed = v ?? false),
                title: const Text(
                  'Saya sudah menulis kata-kata ini di tempat aman',
                  style: TextStyle(fontSize: 14),
                ),
                controlAffinity:
                    ListTileControlAffinity.leading,
                activeColor: const Color(0xFF10B981),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _confirmed
                    ? () => Navigator.pop(context, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Selesai',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
