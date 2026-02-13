{ pkgs, ... }: {
  time.timeZone = "Asia/Tokyo";

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  console.keyMap = "jp106";

  services.xserver.xkb.layout = "jp";

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      kdePackages.fcitx5-qt
      qt6Packages.fcitx5-configtool
    ];
  };

  # Plasma 6 Wayland では Qt6 がネイティブ Wayland IM プロトコルを使うため
  # NixOS モジュールが自動設定する QT_IM_MODULE=fcitx が干渉するのを防ぐ
  environment.sessionVariables.QT_IM_MODULE = "";

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif CJK JP" "Noto Serif" ];
      sansSerif = [ "Noto Sans CJK JP" "Noto Sans" ];
      monospace = [ "Noto Sans Mono CJK JP" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
