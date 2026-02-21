# tmux ビジュアル改善 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** tmux のステータスバーにモードインジケーター・Git ブランチ・日付・時刻を追加し、モダンミニマルなデザインに改善する

**Architecture:** `home/tmux.nix` の `extraConfig` 内のステータスバー・ペインボーダー・メッセージセクションを書き換える。プラグイン追加なし。tmux ビルトインの条件分岐 `#{?...}` とシェルコマンド `#(...)` で全て実現する。

**Tech Stack:** NixOS, Home Manager (`programs.tmux`), tmux extraConfig

**Design doc:** `docs/plans/2026-02-21-tmux-visual-design.md`

---

### Task 1: ステータスバーの status-left を書き換え（モードインジケーター + セッション名）

**Files:**
- Modify: `home/tmux.nix:60-67`

**Step 1: extraConfig のステータスバー左側セクションを書き換える**

`home/tmux.nix` の extraConfig 内で、以下の既存行:

```
set -g status-style "bg=#1a1b26,fg=#c0caf5"
set -g status-left "#[fg=#7aa2f7,bold] #S "
set -g status-left-length 20
```

を以下に置き換える:

```
set -g status-style "bg=#1a1b26,fg=#c0caf5"
set -g status-left-length 40
set -g status-left "#{?client_prefix,#[bg=#e0af68],#{?pane_in_mode,#[bg=#9ece6a],#[bg=#7aa2f7]}}#[fg=#1a1b26,bold] #{?client_prefix,PREFIX,#{?pane_in_mode,COPY,NORMAL}} #[default] #[fg=#7aa2f7,bold]#S #[default]"
```

**ポイント:**
- `#{?client_prefix,...,...}` — prefix キー押下中かどうかで分岐
- `#{?pane_in_mode,...,...}` — コピーモードかどうかで分岐
- `#[default]` — スタイルリセット
- `status-left-length` を 40 に拡大（モードインジケーター分）

---

### Task 2: ステータスバーの status-right を書き換え（Git ブランチ・日付・時刻）

**Files:**
- Modify: `home/tmux.nix:64`

**Step 1: extraConfig のステータスバー右側を書き換える**

既存行:

```
set -g status-right ""
```

を以下に置き換える:

```
set -g status-right-length 60
set -g status-right "#[fg=#9ece6a] #(git -C #{pane_current_path} branch --show-current 2>/dev/null) #[fg=#565f89]%m/%d #[fg=#c0caf5]%H:%M "
```

**ポイント:**
- `#(...)` — シェルコマンド実行（tmux がデフォルト 15 秒間隔でリフレッシュ）
- Git リポジトリ外では空文字が返る（`2>/dev/null`）
- `status-right-length` を 60 に設定（Git ブランチ名が長い場合に備える）

---

### Task 3: ペイン番号表示の色を追加

**Files:**
- Modify: `home/tmux.nix:69-71`

**Step 1: ペインボーダーセクションの後に display-panes の色設定を追加する**

既存のペインボーダーセクション:

```
# --- ペインボーダー ---
set -g pane-border-style "fg=#292e42"
set -g pane-active-border-style "fg=#7aa2f7"
```

の後に以下を追加:

```
set -g display-panes-active-colour "#7aa2f7"
set -g display-panes-colour "#565f89"
```

---

### Task 4: ビルド確認 & コミット

**Step 1: NixOS ビルド確認**

Run: `sudo nixos-rebuild build --flake ~/dotfiles#dev`

Expected: ビルド成功

**Step 2: コミット**

```bash
git add home/tmux.nix
git commit -m "feat: tmux ステータスバーにモードインジケーター・Git ブランチ・時計を追加"
```

---

### Task 5: 適用 & 動作確認

**Step 1: 設定を適用する**

Run: `sudo nixos-rebuild switch --flake ~/dotfiles#dev`

**Step 2: tmux で動作確認**

確認項目:
- ステータスバー左側に「NORMAL」が青背景で表示されること
- `prefix` キー押下中に「PREFIX」が黄背景に変わること
- `prefix + [` でコピーモードに入ると「COPY」が緑背景に変わること
- ステータスバー右側に Git ブランチ名が緑色で表示されること（Git リポジトリ内の場合）
- 日付と時刻が表示されること
- `prefix + q` でペイン番号がアクセントカラーで表示されること
