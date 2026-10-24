# Syncthing で Obsidian の Vault を同期する

NixOS (`dev`) の Obsidian Vault を、Syncthing で Android と Windows に同期する手順です。設定は `system/syncthing.nix` にあります。

## 設定の要点

| 項目 | 値 |
| --- | --- |
| Vault のパス | `/home/user/Documents/Obsidian` |
| folder ID | `obsidian-vault` (`sendreceive`) |
| 設定ディレクトリ | `/home/user/.config/syncthing` (`cert.pem`、`key.pem` を含む) |
| GUI | `http://127.0.0.1:8384`。外部アドレスには公開しない |
| peer | `system/syncthing.nix` の `peers`。登録した peer はすべて `obsidian-vault` の共有先になる |
| バージョン管理 | `staggered`。`maxAge` は 30 日 (`2592000` 秒) |

`peers` の属性名は Nix 内で一意な技術キーです。`name` は Syncthing GUI に表示する名前で、自由に付けられます。

`overrideDevices` と `overrideFolders` が `true` です。GUI で追加した device と folder は、次の `nixos-rebuild switch` で消えます。peer と folder は必ず `system/syncthing.nix` に書きます。

Device ID は認証の secret ではありません。ただし `cert.pem`、`key.pem`、GUI の API key、GUI のパスワードは Git に追加しません。

## 接続ポリシー

NixOS、Android、Windows の全端末で、次の設定を揃えます。NixOS 側は `settings.options` で宣言済みです。

- Global Discovery: off (`globalAnnounceEnabled = false`)
- Relaying: off (`relaysEnabled = false`)
- NAT traversal と UPnP: off (`natEnabled = false`)
- Local Discovery: on (`localAnnounceEnabled = true`)
- peer のアドレス: `dynamic`

同期は同一 LAN 上の自動発見を前提にします。NixOS が hub です。Android と Windows は互いを peer に登録しません。NixOS が止まっている間の変更は各端末に残り、NixOS が再開すると収束します。

`openDefaultPorts = true` は、TCP と UDP の 22000 番、UDP の 21027 番を全 interface で開きます。そのため、厳密な LAN 限定の firewall ではありません。未知の peer は Device ID の相互認証で拒否されます。

## ignore パターン

NixOS 側の ignore パターンは `folders."obsidian-vault".ignorePatterns` で宣言します。NixOS モジュールが Syncthing の REST API (`/rest/db/ignores`) で適用します。除外するのは次のものだけです。

- Obsidian の workspace ファイル (`workspace.json`、`workspace-mobile.json`、`workspaces.json`)
- `.obsidian/` 以下の、原子的書き込みの一時ファイル (`.~*`)
- Syncthing 内部の `.stversions` と `.stfolder`

plugin 本体、plugin の設定、theme、Vault の設定は同期します。

`.stignore` は端末ごとのファイルで、同期されません。Android と Windows にも NixOS と同じパターンを設定します。全端末で folder の **Ignore Permissions** を有効にします (NixOS 側は `ignorePerms = true`)。

`ignorePatterns` を消すときは、先に `ignorePatterns = []` にして適用します。オプションを削除するだけでは、Syncthing に適用済みのパターンは残ります。

## Device ID を確認する

NixOS 側の Device ID を表示するには、次を実行します。

```bash
syncthing device-id --home=/home/user/.config/syncthing
```

## 初回同期を行う

NixOS 側の Vault が空で、Android か Windows に既存の Vault がある場合の手順です。Obsidian Sync と Syncthing を同じ Vault で同時に使いません。

1. 内容が正しいと確認した 1 台だけを NixOS に接続します。
2. NixOS 側が完全に同期したことを確認します。
3. もう 1 台を接続します。

## 新しい peer を追加する

1. 新しい端末で Device ID を取得します。
2. `system/syncthing.nix` の `peers` に追加します。
3. `sudo nixos-rebuild switch --flake ~/dotfiles#dev` を実行します。
4. 新しい端末に NixOS の Device ID を追加します。
5. 新しい端末で folder ID `obsidian-vault` を承認します。
6. 双方向で編集が反映されることを確認します。

## スマホを機種変更する

通常は `cert.pem` と `key.pem` を新しい端末に移しません。新しい端末は別の Device ID で追加します。

1. 旧端末を残したまま、「新しい peer を追加する」の手順で新端末を追加します。
2. 初回同期と、編集の反映を確認します。
3. 旧端末を `peers` から削除して、再適用します。
4. 旧端末のデータを消去します。

## NixOS の再インストール後に Device ID を入れ替える

Syncthing の identity はホストローカルの state です。バックアップも SOPS 管理もしません。`/home/user/.config/syncthing` を失う再インストールでは、NixOS の Device ID が変わります。

Device ID の再登録と Vault の復旧を、複数の peer で同時に行わないでください。

1. 新しい NixOS の Device ID を表示します。
2. Android と Windows に新しい ID を追加します。
3. 既存の peer 1 台から、NixOS の Vault を復元します。
4. NixOS の内容を確認してから、もう 1 台を接続します。
5. 新しい ID で接続と同期ができることを確認します。
6. Android と Windows から、旧 NixOS の ID を削除します。

## リモートから GUI を開く

GUI は `127.0.0.1` だけで待ち受けます。Tailscale SSH 経由で GUI が必要な場合だけ、操作する端末で tunnel を作ります。

```bash
ssh -L 8384:127.0.0.1:8384 user@dev
```

次に、操作する端末で `http://127.0.0.1:8384` を開きます。
