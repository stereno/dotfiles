
# dotfiles

NixOS 専用の設定リポジトリです。

## 構成

```
.
├── flake.nix        # エントリーポイント
├── home/            # home-manager 設定
├── hosts/           # ホスト固有の設定
└── system/          # システム共通設定
```

## 適用

```
sudo nixos-rebuild switch --flake ~/dotfiles#dev
```

## Codex

Codex CLI を Nix で管理しています（`codex`, `codex-acp`）。
認証は OAuth を利用するため、API キーなどの認証情報はこのリポジトリに保存しません。
初回は `codex` または `codex-acp` 実行時にログインして利用します。
