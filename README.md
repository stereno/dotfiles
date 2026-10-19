
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

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#dev
```

## Obsidian / Syncthing

Vault は `/home/user/Documents/Obsidian`、Syncthing GUI はローカルの
`http://127.0.0.1:8384` を使用します。GUI を外部アドレスへ公開しません。

### Device ID

NixOS 側の Device ID は次のコマンドで確認します。

```bash
syncthing device-id --home=/home/user/.config/syncthing
```

同期 peer は `system/syncthing.nix` の `peers` に宣言します。属性名は
Nix 内の一意な技術キー、`name` は Syncthing GUI に表示する自由な名前です。
登録した peer はすべて `obsidian-vault` の共有先になります。

Device ID は認証 secret ではありませんが、`cert.pem`、`key.pem`、GUI API key、
GUI password は Git に追加しません。

### 接続ポリシー

NixOS、Android、Windows の全端末で次の設定を揃えます。

- Global Discovery: off
- Relaying: off
- NAT traversal / UPnP: off
- Local Discovery: on
- peer address: `dynamic`

同一 LAN 上での自動発見・同期を基本とします。NixOS は hub であり、Android と
Windows は互いを直接 peer 登録しません。NixOS が停止している間の変更は各端末に
保持され、NixOS の再開後に収束します。

NixOS の `openDefaultPorts = true` は sync/discovery ports を全 interface で許可するため、
厳密な LAN-only firewall ではありません。未知 peer は Device ID 相互認証で拒否されます。

### 初回同期

NixOS 側の Vault が空で、Android または Windows に既存 Vault がある場合は、内容を
正本と確認した一台だけを最初に接続します。NixOS 側が完全同期になったことを確認してから
もう一台を接続します。Obsidian Sync と Syncthing を同じ Vault で同時利用しません。

NixOS 側の ignore patterns は `system/syncthing.nix` の
`folders."obsidian-vault".ignorePatterns` で宣言し、Syncthing の REST API 経由で
適用します。Workspace、mobile workspace、原子的書き込みの一時ファイルだけを
除外し、plugin 本体・plugin 設定・theme・Vault 設定は同期します。

`.stignore` は端末ローカルで、それ自体は同期されません。NixOS と同じパターンを
Android と Windows にも設定します。全端末で folder の `Ignore Permissions` も
有効にします。

### 新しい peer の追加

1. 新端末で Device ID を取得する。
2. `system/syncthing.nix` の `peers` に追加する。
3. `nixos-rebuild switch` を実行する。
4. 新端末に NixOS の Device ID を追加する。
5. folder ID `obsidian-vault` を承認する。
6. 双方向の smoke test を行う。

### スマホの機種変更

旧端末を残したまま新端末を別 Device ID で追加し、初回同期と編集の反映を確認します。
その後に旧端末を `peers` から削除して再適用し、旧端末を消去します。通常は
`cert.pem` / `key.pem` を新端末へ移しません。

### NixOS 再インストール / Device ID rotation

Syncthing identity は host-local state とし、バックアップや SOPS 管理をしません。
`/home/user/.config/syncthing` を失う再インストールでは NixOS の Device ID が変わります。

1. 新しい NixOS Device ID を表示する。
2. Android と Windows に新 ID を追加する。
3. 一台の既存 peer から NixOS Vault を復元する。
4. NixOS の内容を確認してから、もう一台を接続する。
5. 新 ID の接続・同期を確認する。
6. Android と Windows から旧 NixOS ID を削除する。

Device ID の再登録と Vault の復旧を同時に複数 peer で行わないことが重要です。

### リモート GUI

Tailscale SSH 経由で GUI が必要な場合だけ、操作端末から tunnel を作ります。

```bash
ssh -L 8384:127.0.0.1:8384 user@dev
```

その後、操作端末の `http://127.0.0.1:8384` を開きます。
