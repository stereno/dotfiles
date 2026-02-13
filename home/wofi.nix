{ ... }: {
  programs.wofi = {
    enable = true;

    settings = {
      width = 500;
      height = 350;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 24;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK JP";
        font-size: 14px;
      }

      window {
        background-color: #2e3440;
        border: 2px solid #88c0d0;
        border-radius: 8px;
      }

      #input {
        background-color: #3b4252;
        color: #d8dee9;
        border: none;
        border-radius: 8px;
        padding: 8px 12px;
        margin: 8px;
      }

      #inner-box {
        background-color: transparent;
      }

      #outer-box {
        padding: 8px;
      }

      #entry {
        padding: 6px 12px;
        border-radius: 6px;
        color: #d8dee9;
      }

      #entry:selected {
        background-color: #3b4252;
        color: #88c0d0;
      }
    '';
  };
}
