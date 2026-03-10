{ pkgs, ... }: {
  programs.zed-editor = {
    enable = true;
    installRemoteServer = true;
  };
}
