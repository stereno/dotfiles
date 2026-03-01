{ pkgs, ... }:
let
  sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "black_hole";
  };
in
{
  # Wayland でも SDDM・XWayland のために必要
  services.xserver.enable = true;

  # Display Manager: SDDM (KDE 標準)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = [ sddm-astronaut ];
  };

  environment.systemPackages = [ sddm-astronaut ];

  # AppImage サポート
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # 外部バイナリ用の動的リンカ互換レイヤー
  programs.nix-ld.enable = true;

  # KDE Plasma 6
  services.desktopManager.plasma6.enable = true;

  # オーディオ (GNOME は暗黙的に有効化していたが、KDE では明示的に必要)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
