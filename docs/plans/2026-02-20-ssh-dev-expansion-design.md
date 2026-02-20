# SSH 開発環境拡張 設計ドキュメント

## 概要

Neovim の多言語 LSP 対応と CLI/TUI ツールの導入により、SSH 経由のターミナル開発体験を拡充する。Neovim の「最小限」設計哲学を維持する。

## 背景

- 現在の Neovim は Nix（nil）のみ LSP 対応
- ターミナルでの Git 操作やファイル管理が素のコマンドに依存
- Tailscale SSH + tmux でセッション管理は十分だが、開発ツール面が不足

## 設計

### 1. Neovim 多言語 LSP

`neovim.nix` に LSP サーバーを追加。既存の `vim.lsp.config` / `vim.lsp.enable` パターンを拡張。

**追加 LSP サーバー:**

| 言語 | LSP サーバー | Nix パッケージ |
|------|-------------|---------------|
| TypeScript/JS | typescript-language-server | `nodePackages.typescript-language-server` |
| Python | pyright | `pyright` |
| Go | gopls | `gopls` |
| Rust | rust-analyzer | `rust-analyzer` |

**変更内容:**
- `extraPackages` に各 LSP サーバーを追加
- `vim.lsp.config()` で各 LSP を設定（nil_ls と同パターン）
- `vim.lsp.enable()` に全 LSP を列挙
- Treesitter 対応言語に typescript, python, go, rust を追加
- フォーマッターやリンターは追加しない

### 2. CLI/TUI ツール

新しい `home/cli-tools.nix` モジュールを作成。

**導入ツール:**

| ツール | 用途 |
|--------|------|
| lazygit | Git 操作 TUI |
| yazi | ファイルマネージャー TUI |
| btop | システムモニター |
| bat | cat 代替（シンタックスハイライト） |
| fd | find 代替（高速） |
| jq | JSON 処理 |
| eza | ls 代替（Git 対応） |

**実装:** `home.packages` にまとめるだけ。設定ファイルはデフォルトを使用。

### 3. Neovim - TUI ツール連携

プラグイン追加なし。Neovim ビルトインの `:terminal` を使ったキーバインド2つのみ。

| キー | 動作 |
|------|------|
| `<leader>gg` | lazygit を新タブのターミナルで開く |
| `<leader>e` | yazi を現在ファイルのディレクトリで開く |

Neovim のタブで開くため `gt`/`gT` で行き来可能。tmux との責務重複を避ける。

## 選択しなかったアプローチ

- **B. Neovim 統合型**: toggleterm.nvim 等でプラグイン増加。最小限路線から逸脱
- **C. devShell 統合型**: LSP をプロジェクトごとの devShell で管理。初期セットアップが重く、まずはベースを整えるのが先

## ファイル変更一覧

| ファイル | 変更内容 |
|----------|----------|
| `home/neovim.nix` | LSP サーバー追加、Treesitter 言語追加、キーバインド追加 |
| `home/cli-tools.nix` | 新規作成。TUI/CLI ツールパッケージ |
| `home/default.nix` | cli-tools.nix の import 追加 |
