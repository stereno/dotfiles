{ ... }: {
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };

    settings = {
      # Nord カラー
      foreground = "#d8dee9";
      background = "#2e3440";
      selection_foreground = "#d8dee9";
      selection_background = "#434c5e";
      cursor = "#d8dee9";
      url_color = "#88c0d0";

      # Nord color table
      color0 = "#3b4252";
      color1 = "#bf616a";
      color2 = "#a3be8c";
      color3 = "#ebcb8b";
      color4 = "#81a1c1";
      color5 = "#b48ead";
      color6 = "#88c0d0";
      color7 = "#e5e9f0";
      color8 = "#4c566a";
      color9 = "#bf616a";
      color10 = "#a3be8c";
      color11 = "#ebcb8b";
      color12 = "#81a1c1";
      color13 = "#b48ead";
      color14 = "#8fbcbb";
      color15 = "#eceff4";

      # 外観
      background_opacity = "0.95";
      window_padding_width = 8;
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;

      # カーソル
      cursor_shape = "beam";
      cursor_blink_interval = 0;

      # その他
      scrollback_lines = 10000;
      enable_audio_bell = "no";
      url_style = "curly";
      detect_urls = "yes";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
    };
  };
}
