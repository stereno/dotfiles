{ ... }: {
  services.dunst = {
    enable = true;

    settings = {
      global = {
        width = 350;
        height = 150;
        offset = "16x16";
        origin = "top-right";
        transparency = 10;
        frame_color = "#88c0d0";
        frame_width = 2;
        corner_radius = 8;
        font = "JetBrainsMono Nerd Font 11";
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        show_age_threshold = 60;
        icon_position = "left";
        max_icon_size = 64;
        padding = 12;
        horizontal_padding = 12;
        gap_size = 4;
        separator_color = "frame";
      };

      urgency_low = {
        background = "#2e3440";
        foreground = "#d8dee9";
        timeout = 5;
      };

      urgency_normal = {
        background = "#2e3440";
        foreground = "#d8dee9";
        timeout = 10;
      };

      urgency_critical = {
        background = "#2e3440";
        foreground = "#bf616a";
        frame_color = "#bf616a";
        timeout = 0;
      };
    };
  };
}
