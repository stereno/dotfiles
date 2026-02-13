{ ... }: {
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        grace = 5;
        hide_cursor = true;
      };

      background = [{
        monitor = "";
        path = "screenshot";
        blur_passes = 3;
        blur_size = 6;
        brightness = 0.6;
      }];

      input-field = [{
        monitor = "";
        size = "250, 50";
        outline_thickness = 2;
        outer_color = "rgba(136, 192, 208, 1.0)";
        inner_color = "rgba(59, 66, 82, 1.0)";
        font_color = "rgba(216, 222, 233, 1.0)";
        fade_on_empty = true;
        placeholder_text = "<i>Password...</i>";
        hide_input = false;
        position = "0, -80";
        halign = "center";
        valign = "center";
      }];

      label = [{
        monitor = "";
        text = "$TIME";
        font_size = 64;
        font_family = "JetBrainsMono Nerd Font";
        color = "rgba(216, 222, 233, 1.0)";
        position = "0, 80";
        halign = "center";
        valign = "center";
      }];
    };
  };
}
