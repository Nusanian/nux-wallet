import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';

/// Pengatur bahasa aplikasi: Indonesia default (tampilan lama),
/// pilihan user tersimpan dan bertahan antar-buka aplikasi.
///
/// Bahasa yang didukung: Indonesia ('id') dan English ('en').
/// Tambah bahasa = tambah file app_<kode>.arb + satu entri di
/// [supported] (dan di dialog pilih bahasa di tab Profil).
class LocaleController {
  static const _prefsKey = 'locale';

  static final ValueNotifier<Locale> locale =
      ValueNotifier(const Locale('id'));

  static const supported = [Locale('id'), Locale('en')];

  /// Baca pilihan tersimpan sebelum aplikasi jalan (dipanggil di main).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      locale.value = raw == 'en' ? const Locale('en') : const Locale('id');
    } catch (_) {
      locale.value = const Locale('id');
    }
  }

  static Future<void> setLocale(Locale next) async {
    locale.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.languageCode);
    } catch (_) {
      // Pilihan tetap berlaku sesi ini; gagal simpan bukan fatal.
    }
  }
}

/// Akses string terjemahan dari BuildContext mana pun di bawah
/// MaterialApp: `context.l10n.send`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
