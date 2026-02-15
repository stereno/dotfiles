{ ... }: {
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "TokyoNight Night";
      font-family = "Noto Sans Mono CJK JP";
      font-size = 13;
      adjust-cell-height = "20%";
      background-opacity = 0.92;
      background-blur-radius = 20;
      window-theme = "dark";
      window-padding-x = 8;
      window-padding-y = 4;
      cursor-style = "block";
      copy-on-select = "clipboard";
    };
  };
}
