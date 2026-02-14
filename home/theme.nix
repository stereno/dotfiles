{ pkgs, ... }: {
  # --- パッケージ ---
  home.packages = with pkgs; [
    papirus-icon-theme
    bibata-cursors
    kdePackages.breeze-gtk
  ];

  # --- Plasma (plasma-manager) ---
  programs.plasma = {
    enable = true;

    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      iconTheme = "Papirus-Dark";
      colorScheme = "BreezeDark";
      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
      };
    };

    fonts = {
      general = {
        family = "Inter";
        pointSize = 10;
      };
      fixedWidth = {
        family = "Noto Sans Mono CJK JP";
        pointSize = 10;
      };
      small = {
        family = "Inter";
        pointSize = 8;
      };
      menu = {
        family = "Inter";
        pointSize = 10;
      };
      windowTitle = {
        family = "Inter";
        pointSize = 10;
      };
    };

    kwin.effects = {
      blur = {
        enable = true;
        strength = 10;
        noiseStrength = 0;
      };
      windowOpenClose.animation = "glide";
      minimization.animation = "magiclamp";
    };

    panels = [
      {
        location = "bottom";
        height = 44;
        floating = true;
        widgets = [
          { kickoff = {}; }
          { iconTasks = {}; }
          "org.kde.plasma.marginsseparator"
          {
            digitalClock = {
              time.format = "24h";
              date = {
                enable = true;
                format = "shortDate";
                position = "belowTime";
              };
            };
          }
          { systemTray = {}; }
        ];
      }
    ];

    configFile = {
      "kwinrc"."Compositing" = {
        "Backend" = "OpenGL";
        "GLCore" = true;
      };
      "kdeglobals"."General" = {
        "AccentColor" = "61,174,233";
      };
    };
  };

  # --- GTK テーマ ---
  gtk = {
    enable = true;
    theme = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
    };
    font = {
      name = "Inter";
      size = 10;
    };
  };

  # --- dconf (GTK4/libadwaita ダークモード) ---
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };
}
