{ ... }:
{
  # Tailscale VPN
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # OpenSSH（Tailscale SSH のフォールバック）
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Tailscale インターフェースを信頼
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
