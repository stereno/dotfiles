
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

## Pi Coding Agent sandbox

`pij`（Pi jail）は、Herdr が管理するタスク用 Git worktree を read-write で
disposable NixOS QEMU/KVM VM に渡し、Pi Coding Agent を自動起動する小さな
whole-process launcher です。Pi は VM 内で編集、削除、build、test、子 process、
local Git を自由に使えます。Git の index、refs、新規 objects は session-private で、
終了時に破棄されます。host には worktree のファイル変更だけが残ります。

適用後、Herdr が作成・選択した worktree で実行します。

```bash
pij run .
```

Herdr 内から対話実行した場合は、PIJ が専用の Herdr pane を右側に作ってfocusし、Piを起動します。
caller pane が空か別の agent に使用中かには依存しません。共有 pane の agent authority を
書き換えず、Herdr の process detection により Pi は agent panel に独立して表示されます。
内部の one-time handoff claim は通常の `pij run` における再帰・誤再入・replay 防止用です。
同じ host UID の意図的な内部呼び出しに対する security boundary ではありません。

終了は `Ctrl-D` です。VM と session-private な一時状態は停止・削除されますが、変更は
mount 済みの host worktree にそのまま残るため、host 側で確認できます。`pij` は
worktree の作成・選択・merge を行いません。main branch への統合は、別の
human-approved path が担当します。

root の Pi session は `openai-codex` の `gpt-5.6-terra`、thinking level `medium` で
開始します。これは起動時の既定値であり、bridge による model 強制ではありません。
将来の worker / review model は、それらの runtime を導入するときに別途定義します。

### 信頼境界

選択した worktree のファイルは Pi による破損・削除が可能です。guest 内の local commit
と staging state は session-private であり、VM 終了時に失われます。base history のため
host Git object store だけを read-only で公開しますが、host の refs、config、index、
worktree metadata、新規 objects は guest から変更できません。

一方、次の authority は VM に渡しません。

- host の `$HOME`、unrelated file、SSH agent、credential store
- Nix daemon、container-engine socket、D-Bus、その他の host runtime socket
- reusable OpenAI access/refresh token、および将来の GitHub credential
- 許可されていない repository/branch への GitHub write authority

VM は process、kernel、device、socket、credential、network、resource の境界です。
選択した worktree の file integrity は保護しませんが、shared Git metadata は read-write
authority の外です。CPU、memory、process 数、稼働時間は host の transient systemd
service で制限します。

### OpenAI と network

初期版は general Internet access を持ちません。host-only の薄い OpenAI credential
bridge だけを通して、Pi の native OpenAI Codex transport を利用します。通常の
`~/.pi/agent` とは分離した dedicated auth store で ChatGPT/Codex login を行い、bridge が
refresh と request-time header injection を担当します。access token と refresh token は
guest filesystem、environment、process arguments、generated config、console、worktree に
入りません。

login は host 側だけで実行します。

```bash
pij login
```

専用に制限した pinned Pi が起動したら、`/login` を実行して
`OpenAI (ChatGPT Plus/Pro)` を選び、成功後に `Ctrl-D` で終了します。credential は
`~/.local/state/pij/openai-agent/auth.json` だけに保存されます。この directory は invoking
user 所有かつ group/other access なし、`auth.json` は通常 file かつ同じく private でなければ
拒否されます。また、auth file に `openai-codex` 以外の provider credential があれば拒否します。
通常の `~/.pi/agent`、Hermes credential、将来の GitHub credential とは共有しません。

local credential を削除するには次を実行します。

```bash
pij logout
```

これは local auth file を空の object へ原子的に置き換えるだけで、OpenAI 側の session/token
を server-side revoke しません。credential 漏洩が疑われる場合や完全な失効が必要な場合は、
先に OpenAI account の security/session controls で revoke し、その後 `pij logout` を実行します。
auth store を交換する場合も、directory の symlink 化や権限緩和は行わず、`pij logout` 後に
`pij login` をやり直します。

bridge は OpenAI Codex の `POST /codex/responses` だけを受ける SSE-only transport です。
guest には署名なしの session placeholder JWT と fake account ID だけを渡し、Pi の transport
は `sse` に固定します。bridge は request ごとに pinned Pi の auth command で dedicated store
を refresh し、最新の bearer token と account ID を host 側で注入します。zstd body は展開せず、
prompt と response を記録せずに逐次転送します。general HTTP proxy、WebSocket、Anthropic、
model routing、token/cost budget は実装しません。実 credential を使う smoke test は、明示的な
許可がある場合だけ行います。

### 初期版に含めないもの

- immutable commit ingestion、synthetic baseline、ext4 workspace image、artifact bundle export
- `pi-submit`、host-side quarantine validation、自動 publication / CI loop
- provider-independent model gateway、Anthropic、token/cost policy platform
- GitHub broker、persistent state、resident service、task queue、pstack、Pi-to-Pi orchestration
- general Web access、package registry、Git clone などの直接 egress

将来の機能は実利用の必要性が確認された場合だけ追加します。順序と安全条件は
[Pi agent isolation roadmap](docs/pi-agent-roadmap.md) を参照してください。

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
