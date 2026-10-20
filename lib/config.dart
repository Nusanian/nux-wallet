/// Konfigurasi koneksi ke LSP Nusacoin (MVP).
///
/// Nilai testnet diambil dari BUILD_MACOS.md. Untuk mainnet nanti:
/// ganti ke parameter mainnet dan set [isTestnet] = false.
class AppConfig {
  /// Alamat P2P node LSP, format "host:port" (subdomain, DNS-only).
  static const String lspAddress = 'lsp.taobot.org:9738';

  /// Public key (node id) node LSP — server testnet di VPS
  /// (stabil, diturunkan dari seed.bin yang persisten sejak 19 Okt 2026).
  static const String lspNodeId =
      '02b69d63f7f07765257d729b4141426abff80a91088eb439ec6f2e9669b6423549';

  /// Token akses LSPS2 (bLIP-52) yang dibagikan operator.
  static const String lspToken = 'nux-lsp-test-token';

  /// URL server Electrum (electrs) untuk chain data.
  static const String electrumUrl = 'tcp://lsp.taobot.org:60009';

  /// true = testnet Nusacoin, false = mainnet (Network.nusacoin).
  static const bool isTestnet = true;

  /// true kalau [lspNodeId] sudah diisi nilai aslinya.
  static bool get lspConfigured =>
      lspNodeId.isNotEmpty && lspNodeId != 'GANTI_DENGAN_NODE_ID_LSP';
}
