{ ... }: {
  programs.git = {
    enable = true;
    userName = "stereno";
    userEmail = "160313150+stereno@users.noreply.github.com";
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
