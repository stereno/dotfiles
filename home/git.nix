{ ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.name = "stereno";
      user.email = "160313150+stereno@users.noreply.github.com";
      init.defaultBranch = "main";
      ghq.root = "~/repos";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options.navigate = true;
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
    };
  };
}
