import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux_wallet/theme.dart';

/// Regresi temuan NUX 14 Nov 2026: sesudah ganti font ke Momo
/// Trust Display, angka qty di baris kontrol item pesanan
/// (catatan, diskon, −, qty, +) duduk 5dp TERLALU BAWAH dari
/// tengah vertikal ikon −/+.
///
/// Akar (diukur, bukan ditebak): bentuk lama — Padding top:10 —
/// berasumsi baris rata atas, padahal baris kontrol sempit
/// rata tengah (bawaan Row); kotak baris Momo yang tinggi
/// mendorong angka ke bawah. Bentuk sekarang — kotak 40dp (sama
/// dengan tinggi tombol IconButton compact) + Center + height
/// 1.0 — diukur delta 0,0 di kedua susunan.
///
/// Tes ini memompa REPLIKA susunan itu (metode aslinya privat di
/// state layar, tidak bisa dipompa langsung) dengan konstruksi
/// yang SAMA PERSIS seperti _orderLineActions; bila konstruksi
/// layar berubah, tes ini wajib ikut berubah.
Widget _qty() => const SizedBox(
  height: 40,
  child: Center(
    child: Text('3', style: TextStyle(fontWeight: FontWeight.w700, height: 1.0)),
  ),
);

Widget _controlRow({required Widget qty}) {
  return Row(
    children: [
      IconButton(
        icon: const Icon(Icons.note_add_outlined, size: 19),
        onPressed: () {},
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        icon: const Icon(Icons.percent_rounded, size: 19),
        onPressed: () {},
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        icon: const Icon(Icons.remove_circle_outline, size: 20),
        onPressed: () {},
        visualDensity: VisualDensity.compact,
      ),
      qty,
      IconButton(
        icon: const Icon(Icons.add_circle_outline, size: 20),
        onPressed: () {},
        visualDensity: VisualDensity.compact,
      ),
    ],
  );
}

void main() {
  testWidgets('qty di tengah vertikal ikon: baris kontrol sempit',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: _controlRow(qty: _qty()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final icon = tester.getRect(find.byIcon(Icons.remove_circle_outline));
    final qty = tester.getRect(find.text('3'));
    expect(
      (qty.center.dy - icon.center.dy).abs(),
      lessThanOrEqualTo(0.5),
      reason: 'angka qty harus sejajar tengah ikon minus',
    );
  });

  testWidgets('qty di tengah vertikal ikon: baris lebar + kolom info tinggi',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kopi Susu', style: TextStyle(fontSize: 14)),
                      Text('Rp5.000 x 3', style: TextStyle(fontSize: 12)),
                      Text('Diskon 10%', style: TextStyle(fontSize: 12)),
                      Text('Catatan: tanpa gula',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () {},
                  visualDensity: VisualDensity.compact,
                ),
                _qty(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {},
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final icon = tester.getRect(find.byIcon(Icons.remove_circle_outline));
    final qty = tester.getRect(find.text('3'));
    expect(
      (qty.center.dy - icon.center.dy).abs(),
      lessThanOrEqualTo(0.5),
      reason: 'angka qty harus sejajar tengah ikon minus (susunan lebar)',
    );
  });
}
