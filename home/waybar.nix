{ ... }: {
  programs.waybar = {
    enable = true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 34;
      spacing = 8;

      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "network" "tray" ];

      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
        sort-by-number = true;
      };

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%Y-%m-%d (%a) %H:%M}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = " muted";
        format-icons.default = [ "" "" "" ];
        on-click = "pavucontrol";
      };

      network = {
        format-wifi = " {signalStrength}%";
        format-ethernet = " {ifname}";
        format-disconnected = " disconnected";
        tooltip-format = "{ifname}: {ipaddr}/{cidr}";
      };

      tray.spacing = 8;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK JP";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(46, 52, 64, 0.9);
        border-bottom: 2px solid #3b4252;
        color: #d8dee9;
      }

      #workspaces button {
        padding: 0 8px;
        color: #4c566a;
        border-bottom: 2px solid transparent;
      }

      #workspaces button.active {
        color: #88c0d0;
        border-bottom: 2px solid #88c0d0;
      }

      #workspaces button:hover {
        background: #3b4252;
      }

      #clock, #pulseaudio, #network, #tray {
        padding: 0 12px;
        color: #d8dee9;
      }
    '';
  };
}
