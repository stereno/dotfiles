{ pkgs, ... }: {
  home.packages = with pkgs; [
    obsidian
  ];

  home.file."Documents/Obsidian/.stignore".text = ''
    // Obsidian - 自動更新ファイル（コンフリクトの主因）
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json
    .obsidian/graph.json
    .obsidian/cache

    // プラグイン状態（端末固有）
    .obsidian/plugins/*/data.json

    // Syncthing 内部
    .stversions
    .stfolder
  '';
}
