{ pkgs, ... }: {
  home.packages = with pkgs; [
    claude-code
    tree
  ];
  
  programs.zed-editor = {
    enable = true;
    installRemoteServer = true;
  };
}
