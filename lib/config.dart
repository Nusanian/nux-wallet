/// Konfigurasi koneksi ke LSP Nusacoin (MVP) — VARIAN MAINNET.
///
/// File ini adalah pengganti drop-in untuk lib/config.dart pada build
/// mainnet: nama class dan field sama persis, hanya nilainya yang beda.
/// (Model aplikasi saat ini: satu config per build — lihat REPORT.md.)
class AppConfig {
  /// Alamat P2P node LSP, format "host:port" (subdomain, DNS-only).
  static const String lspAddress = 'lsp.taobot.org:9739';

  /// Public key (node id) node LSP — server mainnet di VPS
  /// (stabil, diturunkan dari seed.bin mainnet yang persisten sejak
  /// 22 Okt 2026; node_id terpanen dari start live 23 Okt 2026).
  static const String lspNodeId =
      '02a3c442a933b1f0a630d56151e84a19f17b662541b2e305a3878b8255c572981a';

  /// Token akses LSPS2 (bLIP-52) yang dibagikan operator.
  /// WAJIB DIGANTI operator dengan token mainnet asli dari
  /// /root/lsp-mainnet/credentials.txt di VPS sebelum build rilis —
  /// nilai asli tidak pernah ditulis di repo/chat.
  static const String lspToken = 'ISI_TOKEN_LSP_MAINNET';

  /// URL server Electrum (electrs) untuk chain data.
  static const String electrumUrl = 'tcp://lsp.taobot.org:50009';

  /// true = testnet Nusacoin, false = mainnet (Network.nusacoin).
  static const bool isTestnet = false;

  /// true kalau [lspNodeId] sudah diisi nilai aslinya.
  static bool get lspConfigured =>
      lspNodeId.isNotEmpty && lspNodeId != 'GANTI_DENGAN_NODE_ID_LSP';
}
