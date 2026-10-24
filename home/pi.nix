{
  config,
  lib,
  pkgs,
  ...
}:
let
  # pi rewrites these files itself (/model, /settings, pi install, /setup-pstack),
  # so they link to the working tree instead of the store. pi's writes land in
  # the checkout and show up in `git diff`.
  writable = [
    "settings.json"
    "mcp.json"
    "pstack-models.md"
  ];
  source = "${config.dotfiles.path}/home/pi";
in
{
  options.dotfiles.path = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/dotfiles";
    description = "Absolute path of this repository's checkout.";
  };

  config = {
    home.packages = [
      pkgs.pi-coding-agent
      pkgs.claude-code # backend CLI for the pi-claude-code package
    ];

    home.file =
      lib.genAttrs (map (name: ".pi/agent/${name}") writable) (target: {
        source = config.lib.file.mkOutOfStoreSymlink "${source}/${baseNameOf target}";
      })
      // {
        # Output of `herdr integration install pi` (integration v8, herdr 0.8.2).
        ".pi/agent/extensions/herdr-agent-state.ts".source = ./pi/herdr-agent-state.ts;
      };

    home.activation.checkDotfilesPath = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for f in ${lib.escapeShellArgs writable}; do
        if [ ! -e ${lib.escapeShellArg source}/"$f" ]; then
          echo "dotfiles.path: ${source}/$f does not exist." >&2
          echo "Set dotfiles.path to this repository's checkout." >&2
          exit 1
        fi
      done
    '';
  };
}
