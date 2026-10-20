# Build Guide — NUX Wallet (macOS)

Self-custodial Lightning wallet untuk Nusacoin (Flutter + LDK + LSPS2 JIT).

## Spesifikasi

| Komponen | Versi |
|----------|-------|
| Flutter | 3.47.7 (stable) |
| Dart | 3.13.5 |
| flutter_rust_bridge_codegen | 2.11.1 |
| Android SDK | API 34 (build-tools 34.0.0) — command line only |
| Java | 17 |
| Rust | stable |

## Persiapan (macOS Ventura)

### 1. Install Homebrew (jika belum)

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

### 2. Install Java 17

```bash
brew install openjdk@17
```

### 3. Install Flutter 3.47.7

```bash
cd ~
git clone https://github.com/flutter/flutter.git -b 3.47.7 flutter-sdk
export PATH="$HOME/flutter-sdk/bin:$PATH"
# Tambahkan ke ~/.zshrc agar permanen:
echo 'export PATH="$HOME/flutter-sdk/bin:$PATH"' >> ~/.zshrc
```

Verifikasi:
```bash
flutter --version
# Harus: Flutter 3.47.7 • Dart 3.13.5
```

### 4. Install Android SDK (tanpa Android Studio)

```bash
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk

# Download command line tools
curl -o tools.zip "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
unzip -q tools.zip -d cmdline-tools
mv cmdline-tools/cmdline-tools cmdline-tools/latest
rm tools.zip

# Set environment
export ANDROID_HOME=$HOME/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

# Tambahkan ke ~/.zshrc:
echo 'export ANDROID_HOME=$HOME/android-sdk' >> ~/.zshrc
echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH' >> ~/.zshrc
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc

# Install komponen yang dibutuhkan
yes | sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Accept licenses
yes | sdkmanager --licenses
```

### 5. Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### 6. Install flutter_rust_bridge_codegen

```bash
cargo install flutter_rust_bridge_codegen --version 2.11.1
```

### 7. Clone binding ldk-node-flutter

```bash
git clone https://github.com/Nusanian/ldk-node-flutter-nux.git
cd ldk-node-flutter-nux
```

## Generate Binding (wajib sebelum build pertama)

```bash
cd ldk-node-flutter-nux

# macOS: install LLVM untuk ffigen
brew install llvm
export LIBCLANG_PATH=$(brew --prefix llvm)/lib

RUSTFLAGS="--cfg tokio_unstable" flutter_rust_bridge_codegen generate
```

Verifikasi: `lib/src/generated/api/types.dart` harus mengandung `nusacoin` di enum `Network`.

## Build APK

```bash
git clone https://github.com/Nusanian/nux-wallet.git
cd nux-wallet
flutter pub get
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

Pindahkan ke HP Android via USB atau AirDrop ke Android File Transfer.

## Konfigurasi LSP

| Parameter | Testnet | Keterangan |
|-----------|---------|------------|
| `lspAddress` | `163.245.193.102:9738` | IP:port LSP |
| `lspNodeId` | (dari operator) | Public key node LSP |
| `lspToken` | `nux-lsp-test-token` | Token LSPS2 |
| `electrumUrl` | `tcp://163.245.193.102:60009` | Electrum TCP |
| `isTestnet` | `true` | `false` untuk mainnet |

Lokasi: `lib/services/lsp_service.dart` → method `init()`

## Troubleshooting (macOS)

### `flutter doctor` komplain Android licenses
```bash
yes | sdkmanager --licenses
flutter doctor --android-licenses
```

### Codegen: "ffigen could not find LLVM"
```bash
brew install llvm
export LIBCLANG_PATH=$(brew --prefix llvm)/lib
```

### Build: "cargo-ndk not found" (untuk Rust native di Android)
```bash
cargo install cargo-ndk
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
```
