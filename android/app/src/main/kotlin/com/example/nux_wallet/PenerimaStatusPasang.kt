package com.example.nux_wallet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.core.content.FileProvider
import java.io.File

// Pasang APK hasil unduhan OTA lewat intent: berkas dibagikan lewat
// FileProvider lalu dibuka installer sistem. Jalur ini terbukti di
// nusan-catcher dan dipakai sebagai jaring pengaman — baik saat
// pembuatan sesi gagal (di MainActivity) maupun saat sesi gagal
// belakangan (di PenerimaStatusPasang).
//
// Urutan fallback dirancang supaya chooser "Open with" tidak muncul:
//
// 1. ACTION_INSTALL_PACKAGE dulu: aksi ini dirancang untuk installer
//    sistem, bukan aplikasi umum seperti ACTION_VIEW, jadi pada
//    umumnya tidak ada daftar aplikasi untuk dipilih.
// 2. Bila itu tidak ada penangan (ActivityNotFoundException), baru
//    ACTION_VIEW yang diarahkan ke paket installer yang dikenali.
//    Daftarnya mencakup varian OEM (Samsung, Xiaomi, OPPO, Vivo),
//    bukan hanya GMS/AOSP. Deteksi ini hanya bisa jalan di Android
//    11+ bila paket-paket itu dideklarasikan di <queries> manifest —
//    tanpa deklarasi itu getPackageInfo melempar NameNotFound meski
//    paketnya ada, dan intent kembali implisit (chooser).
// 3. Bila tidak ada paket yang dikenali, intent dibiarkan implisit
//    (chooser) daripada update gagal total: update yang jalan lewat
//    chooser lebih baik daripada update yang gagal.
internal fun pasangLewatIntent(context: Context, jalur: String) {
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.provider",
        File(jalur),
    )
    val niatPasang = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
        setDataAndType(uri, "application/vnd.android.package-archive")
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    try {
        context.startActivity(niatPasang)
        return
    } catch (_: Exception) {
        // Lanjut ke ACTION_VIEW di bawah.
    }
    val niat = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, "application/vnd.android.package-archive")
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    val paketPemasang = listOf(
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.miui.packageinstaller",
        "com.oppo.packageinstaller",
        "com.vivo.packageinstaller",
    ).firstOrNull { paketTerpasang(context.packageManager, it) }
    if (paketPemasang != null) {
        niat.setPackage(paketPemasang)
    }
    context.startActivity(niat)
}

private fun paketTerpasang(pm: PackageManager, paket: String): Boolean {
    return try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(paket, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(paket, 0)
        }
        true
    } catch (_: Exception) {
        false
    }
}

// Menerima hasil instalasi sesi PackageInstaller. Didaftarkan di
// manifest (bukan dinamis) supaya tetap jalan walau proses aplikasi
// sudah dimatikan sistem selama pemasangan — dan supaya status dari
// versi BARU pun tetap diterima sesudah update berhasil.
//
// Status dikirim sistem lewat PendingIntent eksplisit dari
// MainActivity.pasangLewatSesi, membawa jalur APK di extra
// "jalur_apk" (extra itu dipertahankan sistem saat mengisi status).
// PendingIntent status WAJIB FLAG_MUTABLE: sistem mengisi extra
// hasil (EXTRA_STATUS dan kawan-kawan) ke intent itu, dan pengisian
// gagal bila intent-nya immutable — hasil instalasi jadi tak pernah
// sampai.
//
// Tiga hasil itu WAJIB dibedakan, jangan disatukan:
//
// - STATUS_PENDING_USER_ACTION: BUKAN gagal. Untuk aplikasi biasa
//   (hanya REQUEST_INSTALL_PACKAGES) ini adalah hasil pertama yang
//   normal: sistem meminta konfirmasi pengguna lewat intent di
//   Intent.EXTRA_INTENT, dan intent itu harus dijalankan. Sesudah
//   pengguna mengonfirmasi, sistem mengirim status final (sukses /
//   gagal) lagi ke receiver ini. Mengira status ini gagal lalu
//   langsung melempar fallback intent memunculkan chooser
//   "Open with" di lapangan (temuan nusan-catcher v34→v35,
//   Android 11) meski sesinya tidak gagal. Pengecualian: bila
//   intent konfirmasi tidak ada atau gagal dibuka, receiver jatuh
//   ke jalur cadangan di bawah — tidak ada status yang boleh
//   berakhir buntu tanpa installer maupun pesan.
// - STATUS_SUCCESS: buka kembali aplikasi (versi baru).
// - Status gagal betulan: baru dicoba jalur intent, dan bila itu
//   pun gagal, penyebabnya ditampilkan beserta kode statusnya
//   supaya diagnosa berikutnya tidak buta.
class PenerimaStatusPasang : BroadcastReceiver() {
    override fun onReceive(context: Context, niat: Intent) {
        val status = niat.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val konfirmasi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                niat.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                niat.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            }
            try {
                if (konfirmasi != null) {
                    konfirmasi.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(konfirmasi)
                    return
                }
            } catch (_: Exception) {
                // Jatuh ke penanganan gagal di bawah (jalur cadangan).
            }
            // Intent konfirmasi tidak ada atau gagal dibuka: jangan
            // diam dan jangan hanya Toast — lanjut ke jalur cadangan
            // seperti kegagalan betulan, supaya tidak ada status yang
            // berakhir buntu tanpa installer maupun pesan.
        }
        if (status == PackageInstaller.STATUS_SUCCESS) {
            // Instalasi berhasil: buka kembali aplikasi (versi baru).
            val buka = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(buka)
            return
        }
        val jalur = niat.getStringExtra("jalur_apk")
        val pesan = niat.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
            ?: "tidak diketahui"
        try {
            if (jalur.isNullOrEmpty()) {
                throw IllegalStateException("jalur APK hilang dari status")
            }
            pasangLewatIntent(context, jalur)
        } catch (e: Exception) {
            // Jaring terakhir: jangan diam — tampilkan penyebabnya
            // beserta kode statusnya.
            Toast.makeText(
                context,
                "Gagal memasang update (status $status): $pesan",
                Toast.LENGTH_LONG,
            ).show()
        }
    }
}
