import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux_wallet/theme.dart';
import 'package:nux_wallet/widgets/transaction_row.dart';

Future<void> _pumpRow(
  WidgetTester tester, {
  required double width,
  String? status,
  bool statusBad = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TransactionRow(
              icon: const Icon(Icons.arrow_downward_rounded, size: 22),
              title: 'Diterima',
              addr: '31ea7…d8b1',
              tag: '⚡ JIT',
              isIn: true,
              amount: '+1.000',
              time: '20.48',
              status: status,
              statusBad: statusBad,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
      'chip Menunggu di baris ke-3: di bawah baris ID, tidak menabrak '
      'kolom nominal/waktu', (tester) async {
    await _pumpRow(tester, width: 320, status: 'Menunggu');
    expect(tester.takeException(), isNull);

    final addrRect = tester.getRect(find.text('31ea7…d8b1'));
    final statusRect = tester.getRect(find.text('Menunggu'));
    final amountRect = tester.getRect(find.text('+1.000'));
    final timeRect = tester.getRect(find.text('20.48'));

    // Baris ke-3: chip status mulai di bawah baris ID+chip jenis.
    expect(statusRect.top, greaterThan(addrRect.bottom - 1));
    // Tidak bertabrakan dengan kolom kanan (kasus lama: chip
    // terpotong sampai menempel teks waktu).
    expect(statusRect.overlaps(amountRect), isFalse);
    expect(statusRect.overlaps(timeRect), isFalse);
    expect(statusRect.right, lessThan(amountRect.left));
  });

  testWidgets('chip Gagal juga di baris ke-3', (tester) async {
    await _pumpRow(tester, width: 320, status: 'Gagal', statusBad: true);
    expect(tester.takeException(), isNull);
    final addrRect = tester.getRect(find.text('31ea7…d8b1'));
    final statusRect = tester.getRect(find.text('Gagal'));
    expect(statusRect.top, greaterThan(addrRect.bottom - 1));
  });

  testWidgets('tanpa status (sukses): tidak ada baris chip',
      (tester) async {
    await _pumpRow(tester, width: 320);
    expect(tester.takeException(), isNull);
    expect(find.text('Menunggu'), findsNothing);
    expect(find.text('Diterima'), findsOneWidget);
  });

  testWidgets('lebar sangat sempit 260: tetap tanpa luapan',
      (tester) async {
    await _pumpRow(tester, width: 260, status: 'Menunggu');
    expect(tester.takeException(), isNull);
    final statusRect = tester.getRect(find.text('Menunggu'));
    final timeRect = tester.getRect(find.text('20.48'));
    expect(statusRect.overlaps(timeRect), isFalse);
  });
}
