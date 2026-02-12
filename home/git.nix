{ ... }: {
  programs.git = {
    enable = true;
    userName = "stereno";
    userEmail = "stereno@proton.me";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
    };
  };
}
