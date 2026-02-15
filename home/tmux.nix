{ pkgs, ... }: {
  programs.tmux = {
    enable = true;
    prefix = "C-b";
    mouse = true;
    terminal = "tmux-256color";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    keyMode = "vi";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      {
        plugin = resurrect;
        extraConfig = "set -g @resurrect-capture-pane-contents 'on'";
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];

    extraConfig = ''
      # --- ペイン移動（Vim 方向キー） ---
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # --- ペインリサイズ ---
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # --- ペイン分割（直感的な記号 + 現在のディレクトリを引き継ぎ） ---
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # --- コピーモード強化（Vim ライク） ---
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # --- 新規ウィンドウで現在のディレクトリを引き継ぎ ---
      bind c new-window -c "#{pane_current_path}"

      # --- 設定リロード ---
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

      # --- ペイン番号も 1 から ---
      set -g pane-base-index 1
      set -g renumber-windows on

      # --- ステータスバー（TokyoNight Night テーマ） ---
      set -g status-style "bg=#1a1b26,fg=#c0caf5"
      set -g status-left "#[fg=#7aa2f7,bold] #S "
      set -g status-left-length 20
      set -g status-right ""
      set -g window-status-format "#[fg=#565f89] #I:#W "
      set -g window-status-current-format "#[fg=#7aa2f7,bg=#292e42,bold] #I:#W "
      set -g window-status-separator ""

      # --- ペインボーダー ---
      set -g pane-border-style "fg=#292e42"
      set -g pane-active-border-style "fg=#7aa2f7"

      # --- メッセージ ---
      set -g message-style "bg=#292e42,fg=#c0caf5"
    '';
  };
}
