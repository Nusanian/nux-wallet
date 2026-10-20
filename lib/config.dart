/// Konfigurasi koneksi ke LSP Nusacoin (MVP).
///
/// Nilai testnet diambil dari BUILD_MACOS.md. Untuk mainnet nanti:
/// ganti ke parameter mainnet dan set [isTestnet] = false.
class AppConfig {
  /// Alamat P2P node LSP, format "host:port" (subdomain, DNS-only).
  static const String lspAddress = 'lsp.taobot.org:9738';

  /// Public key (node id) node LSP — WAJIB diisi operator sebelum build.
  /// Selama masih placeholder, aplikasi menampilkan pesan error yang jelas
  /// saat dibuka (bukan crash misterius).
  static const String lspNodeId = 'GANTI_DENGAN_NODE_ID_LSP';

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
