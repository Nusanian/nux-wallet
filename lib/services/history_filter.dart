import 'package:ldk_node/src/generated/api/types.dart';

/// Pilihan rentang filter tanggal tab Riwayat.
///
/// Tampilan bawaan adalah [last7Days] (keputusan NUX 2 Nov 2026):
/// riwayat lama tidak memenuhi layar, tetapi selalu bisa dijangkau
/// lewat [last30Days] atau rentang tanggal pilihan sendiri [custom].
/// Ekspor CSV mengikuti filter yang sama persis dengan yang tampil.
enum HistoryRangePreset { last7Days, last30Days, custom }

/// Batas rentang tampil: [start] inklusif, [endExclusive] eksklusif
/// (null = tanpa batas atas).
typedef HistoryRange = ({DateTime start, DateTime? endExclusive});

/// Hitung rentang untuk [preset] relatif terhadap [now].
///
/// Preset berjalan memakai jendela bergulir 7/30 × 24 jam dari
/// [now]. [customStart]/[customEnd] hanya dipakai preset custom
/// dan diperlakukan sebagai hari kalender utuh: dari awal hari
/// pertama sampai awal hari sesudah hari terakhir, supaya tanggal
/// akhir pilihan pemilih tanggal ikut tercakup seluruhnya.
HistoryRange historyRangeForPreset(
  HistoryRangePreset preset, {
  required DateTime now,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  switch (preset) {
    case HistoryRangePreset.last7Days:
      return (start: now.subtract(const Duration(days: 7)), endExclusive: null);
    case HistoryRangePreset.last30Days:
      return (
        start: now.subtract(const Duration(days: 30)),
        endExclusive: null,
      );
    case HistoryRangePreset.custom:
      final s = customStart ?? now;
      final e = customEnd ?? s;
      return (
        start: DateTime(s.year, s.month, s.day),
        endExclusive: DateTime(
          e.year,
          e.month,
          e.day,
        ).add(const Duration(days: 1)),
      );
  }
}

/// Waktu pembayaran menurut catatan node (cap unix detik),
/// ditafsirkan sama seperti pada ekspor CSV.
DateTime paymentDateTime(PaymentDetails payment) =>
    DateTime.fromMillisecondsSinceEpoch(
      payment.latestUpdateTimestamp.toInt() * 1000,
    );

/// Saring [payments] ke yang waktu terbarunya berada di [range].
/// Urutan masukan dipertahankan (terbaru di depan).
List<PaymentDetails> filterPaymentsByRange(
  List<PaymentDetails> payments,
  HistoryRange range,
) => payments.where((p) {
  final t = paymentDateTime(p);
  if (t.isBefore(range.start)) return false;
  final end = range.endExclusive;
  if (end != null && !t.isBefore(end)) return false;
  return true;
}).toList();
