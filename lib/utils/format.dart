/// Format nominal Lightning untuk tampilan.
///
/// Nilai sumber selalu msat (millisatoshi versi Nusacoin). Satuan
/// tampilan utama adalah nusan (1 nusan = 1000 msat), dengan pemisah
/// ribuan gaya id_ID ('.') dan desimal ',' bila ada sisa msat.
String formatNusan(BigInt msat) {
  final negative = msat < BigInt.zero;
  final abs = msat.abs();
  final whole = abs ~/ BigInt.from(1000);
  final rem = (abs % BigInt.from(1000)).toInt();

  final digits = whole.toString();
  final buf = StringBuffer();
  if (negative) buf.write('-');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  if (rem != 0) {
    var frac = rem.toString().padLeft(3, '0');
    while (frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    buf.write(',$frac');
  }
  return buf.toString();
}

/// Format waktu transaksi untuk daftar aktivitas/riwayat.
///
/// Hari ini → jam 'HH.mm'; kemarin → 'Kemarin'; lebih lama → 'd MMM'
/// dengan singkatan bulan Indonesia. [now] bisa diisi untuk pengujian.
String formatTxTime(DateTime time, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  final diffDays = today.difference(day).inDays;
  if (diffDays == 0) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh.$mm';
  }
  if (diffDays == 1) return 'Kemarin';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${time.day} ${months[time.month - 1]}';
}
