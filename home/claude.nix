{ ... }: {
  home.file.".claude/statusline.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      input=$(cat)

      ctx=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
      added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
      removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

      branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
      time=$(date +"%H:%M")

      bar_width=10
      filled=$((ctx * bar_width / 100))
      empty=$((bar_width - filled))
      bar=""
      for ((i=0; i<filled; i++)); do bar+="█"; done
      for ((i=0; i<empty; i++)); do bar+="░"; done

      out="$bar ''${ctx}%  +''${added} -''${removed}"
      [ -n "$branch" ] && out="$out  $branch"
      out="$out  $time"

      echo "$out"
    '';
  };
}
