{ config, ... }: {
  services.syncthing = {
    enable = true;
    user = "user";
    dataDir = config.users.users.user.home;
    openDefaultPorts = true;

    settings = {
      options.urAccepted = -1;

      folders."obsidian-vault" = {
        path = "${config.users.users.user.home}/Documents/Obsidian";
        devices = [];
        versioning = {
          type = "staggered";
          params.maxAge = "2592000";
        };
      };
    };

    overrideDevices = false;
    overrideFolders = true;
  };
}
