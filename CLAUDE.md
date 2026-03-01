# Dotfiles

NixOS + home-manager + flakes で管理する個人設定リポジトリ。

## 構成

```
flake.nix          # エントリーポイント (nixosConfigurations.dev)
home/              # home-manager モジュール (shell, git, neovim, tmux, etc.)
  default.nix      # 全モジュールの import
system/            # NixOS システムモジュール (desktop, locale, nix, etc.)
  default.nix      # 全モジュールの import
hosts/dev/         # ホスト固有設定 + hardware-configuration.nix
```

## デプロイ

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#dev
```

- `nixos-rebuild` は基本的にユーザーが手動で行う。Claude が勝手に実行しないこと
- 変更後はユーザーに `rebuild-dev` の実行を促す

## Nix 記述ルール

- `home/` 配下のモジュールは `{ pkgs, ... }:` や `{ config, lib, pkgs, ... }:` の形式で始める
- 新しい home-manager モジュールを作成したら `home/default.nix` の imports に追加する
- 新しい system モジュールを作成したら `system/default.nix` の imports に追加する
- `'' ''` (indented string) 内で Bash 変数 `${var}` を使う場合は `''${var}` とエスケープする
- nixpkgs は unstable チャネルを使用している

## Git

- コミットメッセージは日本語で書く（タイトルのプレフィックスは英語: feat, fix, update, etc.）
- 過去のコミット例: `feat: Claude Code statusline スクリプトを home-manager で管理`
