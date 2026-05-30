{ ... }: {
  home.file.".claude/statusline.sh" = {
    executable = true;
    source = ./claude/statusline.sh;
  };

  home.file.".claude/mcp.json".text = builtins.toJSON {
    mcpServers = {
      codex = {
        type    = "stdio";
        command = "codex";
        args    = [ "mcp" ];
      };
    };
  };
}
