# Build Guide — NUX Wallet

Self-custodial Lightning wallet untuk Nusacoin (Flutter + LDK + LSPS2 JIT).

## Spesifikasi

| Komponen | Versi |
|----------|-------|
| Flutter | 3.47.7 (stable) |
| Dart | 3.13.5 |
| flutter_rust_bridge_codegen | 2.11.1 |
| Android SDK | API 34 (build-tools 34.0.0) |
| Java | 17 (untuk Android build) |
| Rust | stable (untuk codegen) |

## Persiapan (sekali saja)

### 1. Install Flutter

Download Flutter 3.47.7 dari https://docs.flutter.dev/release/archive
Extract dan tambahkan `bin/` ke PATH.

```bash
flutter --version
# Harus: Flutter 3.47.7 • Dart 3.13.5
```

### 2. Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 3. Install flutter_rust_bridge_codegen

```bash
cargo install flutter_rust_bridge_codegen --version 2.11.1
```

### 4. Install Android Studio (untuk APK)

Download dari https://developer.android.com/studio
Install Android SDK API 34 + build-tools 34.0.0 via SDK Manager.

### 5. Clone binding ldk-node-flutter

```bash
git clone https://github.com/Nusanian/ldk-node-flutter-nux.git
cd ldk-node-flutter-nux
```

## Generate Binding (wajib sebelum build pertama)

Binding Dart dari Rust harus di-generate ulang karena file
`frb_generated.dart` tidak ikut ter-push (terlalu besar untuk GitHub API).

```bash
cd ldk-node-flutter-nux

# Linux: butuh clang shim jika belum ada clang
# mkdir -p ~/bin && ln -sf $(which gcc) ~/bin/clang

# Linux: butuh libclang untuk ffigen
# sudo apt-get install libclang-dev

RUSTFLAGS="--cfg tokio_unstable" flutter_rust_bridge_codegen generate
```

Verifikasi: file `lib/src/generated/api/types.dart` harus mengandung
`nusacoin` di enum `Network`.

## Build APK

```bash
git clone https://github.com/Nusanian/nux-wallet.git
cd nux-wallet
flutter pub get
flutter build apk --release
```

APK hasil: `build/app/outputs/flutter-apk/app-release.apk`

## Konfigurasi LSP

Edit `lib/services/lsp_service.dart` atau buat config:

| Parameter | Testnet | Keterangan |
|-----------|---------|------------|
| `lspAddress` | `163.245.193.102:9738` | Ganti dengan domain produksi |
| `lspNodeId` | (dari operator) | Public key node LSP |
| `lspToken` | `nux-lsp-test-token` | Token akses LSPS2 |
| `electrumUrl` | `tcp://163.245.193.102:60009` | Ganti dengan wss:// produksi |
| `isTestnet` | `true` | `false` untuk mainnet |

## Troubleshooting

### Codegen gagal: "ffigen could not find LLVM"
Install libclang:
- Ubuntu: `sudo apt-get install libclang-dev`
- Windows: install LLVM dari https://llvm.org/builds/

### Codegen gagal: "failed to find tool clang"
Buat shim: `ln -sf $(which gcc) ~/bin/clang` dan tambahkan ke PATH.

### Build Android gagal: Rust native
Pastikan `cargo-ndk` terinstall untuk cross-compile Rust ke Android:
```bash
cargo install cargo-ndk
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
```

## Struktur Project

```
lib/
├── main.dart                 # UI Home + navigasi
├── services/
│   └── lsp_service.dart      # LDK node + LSPS2/JIT
└── screens/
    ├── receive_screen.dart   # Buat invoice JIT
    ├── send_screen.dart      # Bayar invoice
    └── backup_screen.dart    # Backup 12 kata
```
