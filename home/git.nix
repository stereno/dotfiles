{ ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.name = "stereno";
      user.email = "160313150+stereno@users.noreply.github.com";
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
