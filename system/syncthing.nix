{ config, ... }:
let
  peers = {
    windows = {
      id = "UAPGSY5-T6YVXGR-SFYOP2G-6JNAL7R-PKIGEXQ-5OCZ3K7-TGFHYUG-MGEUYA4";
      name = "Windows";
      addresses = [ "dynamic" ];
    };

    "nothing-2a" = {
      id = "E2VY7YC-EHVEC3S-TBRFKCZ-XOTYOV4-N6Q3CQV-MTMX3EC-WAUZKZC-DW3NEA4";
      name = "Nothing Phone (2a)";
      addresses = [ "dynamic" ];
    };
  };
in
{
  services.syncthing = {
    enable = true;
    user = "user";
    dataDir = config.users.users.user.home;
    guiAddress = "127.0.0.1:8384";
    openDefaultPorts = true;

    settings = {
      devices = peers;

      folders."obsidian-vault" = {
        path = "${config.users.users.user.home}/Documents/Obsidian";
        devices = builtins.attrNames peers;
        type = "sendreceive";
        ignorePerms = true;
        ignorePatterns = [
          "// Obsidian: 端末固有で頻繁に更新されるUI状態"
          "(?d)/.obsidian/workspace.json"
          "(?d)/.obsidian/workspace-mobile.json"
          "(?d)/.obsidian/workspaces.json"

          "// Obsidian/plugin: 原子的書き込みの一時ファイル"
          "(?d)/.obsidian/**/.~*"

          "// Syncthing内部"
          "(?d)/.stversions"
          "(?d)/.stfolder"
        ];
        versioning = {
          type = "staggered";
          params.maxAge = "2592000";
        };
      };

      options = {
        globalAnnounceEnabled = false;
        localAnnounceEnabled = true;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
      };
    };

    overrideDevices = true;
    overrideFolders = true;
  };
}
