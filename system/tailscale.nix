{ ... }:
{
  # Tailscale VPN
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [ "--ssh" ];
  };

  # OpenSSH（Tailscale SSH のフォールバック）
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Tailscale インターフェースのみ信頼・SSH 許可
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
