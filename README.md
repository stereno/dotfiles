
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
