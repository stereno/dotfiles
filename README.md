# dotfiles

1 台のマシン (`dev`) 用の NixOS と home-manager の設定です。Nix flake で管理します。

このリポジトリは GitHub で公開しています。認証情報、秘密鍵、トークンはコミットしません。

## ディレクトリ構成

```
.
├── flake.nix        # エントリーポイント。inputs と outputs を定義する
├── flake.lock
├── hosts/dev/       # ホスト dev 固有の設定とハードウェア設定
├── system/          # NixOS の共通モジュール (デスクトップ、Tailscale、Syncthing など)
├── home/            # home-manager のモジュール。home/nvim/ は Neovim の Lua 設定
├── docs/            # 運用手順
├── .pi/extensions/  # pi エージェントの拡張 (commit-gate.ts)
├── AGENTS.md        # エージェント向けのルール
├── statix.toml      # statix の設定
└── .envrc           # direnv で devShell を読み込む
```

## flake の出力

| 出力 | 内容 |
| --- | --- |
| `nixosConfigurations.dev` | `hosts/dev` と `system/` に、home-manager の `home/default.nix` を組み込んだ NixOS 構成 |
| `homeConfigurations.core` | `home/core.nix`。シェル、Git、Neovim、tmux、CLI ツール |
| `homeConfigurations.desktop` | `home/desktop.nix`。`core` にターミナル、ブラウザ、テーマ、Obsidian、開発ツールを加えたもの |
| `checks.x86_64-linux` | pre-commit フックと、ツリー全体の gitleaks スキャン |
| `devShells.x86_64-linux.default` | pre-commit フックを入れる開発シェル |
| `formatter.x86_64-linux` | `nixfmt-tree` |

## 設定を適用する

NixOS に適用するには、次を実行します。

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#dev
```

NixOS 以外で home-manager だけを適用するには、次を実行します。`desktop` の代わりに `core` も使えます。

```bash
nix run home-manager -- switch --flake ~/dotfiles#desktop
```

## 開発する

1. リポジトリのルートで `direnv allow` を実行します。direnv がない場合は `nix develop -c true` を実行します。どちらも pre-commit フックをインストールします。
2. Nix ファイルを編集します。
3. `nix fmt` で整形します。
4. `nix flake check` でフックをツリー全体に実行します。
5. `nixos-rebuild build --flake .#dev` で、適用せずにビルドします。

pre-commit フックは gitleaks、detect-private-keys、nixfmt、statix、deadnix を実行します。フックが失敗したら、指摘を直してからコミットします。`--no-verify` でフックを飛ばしません。

エージェント向けのルールは [AGENTS.md](AGENTS.md) にあります。

## Obsidian と Syncthing

Obsidian の Vault は Syncthing で Android と Windows に同期します。手順は [Syncthing で Obsidian の Vault を同期する](docs/syncthing.md) を参照してください。
