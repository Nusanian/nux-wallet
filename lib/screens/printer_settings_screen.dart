import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../locale_controller.dart';
import '../services/print_service.dart';
import '../theme.dart';

/// Halaman Pengaturan Printer — pilih printer struk 58mm yang
/// sudah ter-pairing, uji cetak, dan atur teks header/footer
/// struk (dipakai juga nanti oleh mini POS).
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  PrinterSettings _settings = const PrinterSettings();
  List<BluetoothInfo> _paired = const [];
  bool _loaded = false;
  bool _printing = false;
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await PrintService.loadSettings();
    final paired = await PrintService.pairedPrinters();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _paired = paired;
      _headerController.text = settings.headerText;
      _footerController.text = settings.footerText;
      _loaded = true;
    });
  }

  Future<void> _pickPrinter() async {
    final l10n = context.l10n;
    if (_paired.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.printerNoPaired)));
      return;
    }
    final picked = await showDialog<BluetoothInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.card,
        title: Text(l10n.printerSelect),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final device in _paired)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(device.name),
                subtitle: Text(device.macAdress),
                trailing: device.macAdress == _settings.macAddress
                    ? const Icon(Icons.check_rounded, color: Color(0xFF34D399))
                    : null,
                onTap: () => Navigator.pop(ctx, device),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final next = _settings.copyWith(
      macAddress: picked.macAdress,
      printerName: picked.name,
    );
    setState(() => _settings = next);
    await PrintService.saveSettings(next);
  }

  Future<void> _testPrint() async {
    setState(() => _printing = true);
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final timeText =
        '${two(now.day)}-${two(now.month)}-${now.year} ${two(now.hour)}:${two(now.minute)}';
    final outcome = await PrintService.printTest(
      settings: _settings,
      testTitle: context.l10n.printerTest,
      timeText: timeText,
      defaultFooter: context.l10n.receiptDefaultFooter,
    );
    if (!mounted) return;
    setState(() => _printing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(printOutcomeMessage(context.l10n, outcome))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.printerSettings),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.palette.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.print_rounded,
                            color: Color(0xFF34D399),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _settings.hasPrinter
                                      ? _settings.printerName
                                      : l10n.printerNoneSelected,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_settings.hasPrinter) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    _settings.macAddress,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.palette.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickPrinter,
                              child: Text(l10n.printerSelect),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _printing ? null : _testPrint,
                              child: Text(l10n.printerTest),
                            ),
                          ),
                        ],
                      ),
                      if (_paired.isEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          l10n.printerNoPaired,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.printerHeader,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.printerHeaderHint,
                  style: TextStyle(fontSize: 12, color: context.palette.muted),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _headerController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'ELNUX',
                  ),
                  onChanged: (value) {
                    _settings = _settings.copyWith(headerText: value);
                    PrintService.saveSettings(_settings);
                  },
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.printerFooter,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.printerFooterHint,
                  style: TextStyle(fontSize: 12, color: context.palette.muted),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _footerController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: l10n.receiptDefaultFooter,
                  ),
                  onChanged: (value) {
                    _settings = _settings.copyWith(footerText: value);
                    PrintService.saveSettings(_settings);
                  },
                ),
              ],
            ),
    );
  }
}
