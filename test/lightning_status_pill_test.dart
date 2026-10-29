import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux_wallet/widgets/lightning_status_pill.dart';

/// Pil status harus muat di lebar berapa pun, bahasa apa pun, dan
/// skala teks berapa pun, tanpa error luapan (overflow) dan tanpa
/// melebihi lebar yang diberikan.
Future<void> _pumpPill(
  WidgetTester tester, {
  required double width,
  required String label,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: LightningStatusPill(active: true, label: label),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  const idLabel = 'Lightning aktif — siap terima instan';
  const enLabel = 'Lightning active — ready for instant receive';

  testWidgets('lebar normal: tampil utuh tanpa luapan', (tester) async {
    await _pumpPill(tester, width: 360, label: idLabel);
    expect(tester.takeException(), isNull);
    expect(find.text(idLabel), findsOneWidget);
    final pillWidth =
        tester.getSize(find.byType(LightningStatusPill)).width;
    expect(pillWidth, lessThanOrEqualTo(360));
  });

  testWidgets('layar sempit 240 + teks Inggris panjang: tidak meluap',
      (tester) async {
    await _pumpPill(tester, width: 240, label: enLabel);
    expect(tester.takeException(), isNull);
    final pillWidth =
        tester.getSize(find.byType(LightningStatusPill)).width;
    expect(pillWidth, lessThanOrEqualTo(240));
  });

  testWidgets('layar sangat sempit 180 + skala teks 2x: tetap aman',
      (tester) async {
    await _pumpPill(tester, width: 180, label: enLabel, textScale: 2.0);
    expect(tester.takeException(), isNull);
    final pillWidth =
        tester.getSize(find.byType(LightningStatusPill)).width;
    expect(pillWidth, lessThanOrEqualTo(180));
  });

  testWidgets('lebar kartu saldo HP kecil (324): teks ID muat',
      (tester) async {
    // Kartu saldo: margin 18*2 + padding 24*2 → lebar isi pada HP
    // 360dp adalah 276; 324 di sini lebar pil maksimum yang diuji
    // lebih longgar dari itu, dan kasus 240/180 di atas menutup
    // yang lebih sempit.
    await _pumpPill(tester, width: 324, label: idLabel);
    expect(tester.takeException(), isNull);
  });
}
