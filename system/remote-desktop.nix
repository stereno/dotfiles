{ pkgs, ... }:
let
  displayOutput = "HDMI-A-1";
  originalMode = "1920x1200@59.95";
  kscreen = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor";
in
{
  # Sunshine ストリーミングサーバー（リモートデスクトップ用）
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true; # Wayland/KMS キャプチャに必須
    openFirewall = true; # TCP 47984-47990,48010 / UDP 47998-48000,48010
  };

  # 仮想入力デバイス（マウス・キーボード）に必要
  hardware.uinput.enable = true;

  # KWin にソフトウェアカーソルを強制（KMS キャプチャにカーソルを含めるため）
  environment.sessionVariables.KWIN_FORCE_SW_CURSOR = "1";

  # AMD ハードウェアビデオアクセラレーション（VAAPI）
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };
}
