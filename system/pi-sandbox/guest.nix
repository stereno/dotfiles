{ lib, piAgent, piModels, pkgs, ... }:
let
  piSessionShutdown = pkgs.writeShellApplication {
    name = "pi-session-shutdown";
    text = ''
      ${pkgs.coreutils}/bin/sync
      ${pkgs.util-linux}/bin/umount /workspace/repo/.git 2>/dev/null || true
      ${pkgs.util-linux}/bin/umount /workspace/repo 2>/dev/null || true
      ${pkgs.util-linux}/bin/umount /workspace/git-objects 2>/dev/null || true
      ${pkgs.coreutils}/bin/sync
      ${pkgs.systemd}/bin/systemctl --force --force poweroff
    '';
  };
  piSessionShell = (pkgs.writeShellApplication {
    name = "pi-session-shell";
    text = ''
      cd /workspace/repo
      exec env \
        HOME=/workspace/home \
        PI_CODING_AGENT_DIR=/workspace/home/.pi/agent \
        PI_TELEMETRY=0 \
        ${piAgent}/bin/pi \
          --provider ${piModels.main.provider} \
          --model ${piModels.main.model} \
          --thinking ${piModels.main.thinking} \
          --no-extensions \
          --no-approve
    '';
  }) // {
    shellPath = "/bin/pi-session-shell";
  };
in
{
  system.stateVersion = "25.11";

  networking.hostName = "pi-sandbox";
  networking.useDHCP = false;
  networking.nameservers = lib.mkForce [ ];
  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "10.0.2.15";
      prefixLength = 24;
    }
  ];

  nix.enable = false;

  users.users.agent = {
    isNormalUser = true;
    uid = 1000;
    group = "agent";
    home = "/workspace/home";
    createHome = false;
    shell = piSessionShell;
  };
  users.groups.agent.gid = 1000;

  services.getty.autologinUser = "agent";
  security.sudo.enable = false;

  virtualisation.fileSystems = {
    "/workspace/repo" = {
      device = "pij-worktree";
      fsType = "9p";
      neededForBoot = true;
      options = [
        "trans=virtio"
        "version=9p2000.L"
        "msize=1048576"
        "cache=none"
        "rw"
        "nodev"
        "nosuid"
        "x-systemd.requires=modprobe@9pnet_virtio.service"
      ];
    };
    "/workspace/git-objects" = {
      device = "pij-git-objects";
      fsType = "9p";
      neededForBoot = true;
      options = [
        "trans=virtio"
        "version=9p2000.L"
        "msize=1048576"
        "cache=none"
        "ro"
        "nodev"
        "nosuid"
        "noexec"
        "x-systemd.requires=modprobe@9pnet_virtio.service"
      ];
    };
    "/run/pij/session" = {
      device = "pij-session";
      fsType = "9p";
      neededForBoot = true;
      options = [
        "trans=virtio"
        "version=9p2000.L"
        "msize=65536"
        "cache=none"
        "ro"
        "nodev"
        "nosuid"
        "noexec"
        "x-systemd.requires=modprobe@9pnet_virtio.service"
      ];
    };
  };

  systemd.services.pi-workspace-init = {
    description = "Prepare the read-write linked Git worktree for Pi";
    wantedBy = [ "multi-user.target" ];
    after = [ "workspace-repo.mount" "workspace-git\\x2dobjects.mount" "run-pij-session.mount" ];
    requires = [ "workspace-repo.mount" "workspace-git\\x2dobjects.mount" "run-pij-session.mount" ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      set -euo pipefail
      test -f /workspace/repo/.git
      test ! -L /workspace/repo/.git
      base_commit=$(< /run/pij/session/base-commit)
      object_format=$(< /run/pij/session/object-format)
      [[ $base_commit =~ ^[0-9a-f]{40}$|^[0-9a-f]{64}$ ]]
      [[ $object_format == sha1 || $object_format == sha256 ]]

      install -d -o agent -g agent -m 0700 /workspace/home
      install -d -o agent -g agent -m 0700 /workspace/home/.pi/agent
      ${pkgs.util-linux}/bin/runuser -u agent -- \
        ${pkgs.git}/bin/git init --bare --quiet \
          --object-format="$object_format" /workspace/home/git
      printf "/workspace/git-objects\n" > /workspace/home/git/objects/info/alternates
      printf "ref: refs/heads/pij-session\n" > /workspace/home/git/HEAD
      install -d -o agent -g agent -m 0755 /workspace/home/git/refs/heads
      printf "%s\n" "$base_commit" > /workspace/home/git/refs/heads/pij-session
      chown -R agent:agent /workspace/home/git
      ${pkgs.util-linux}/bin/runuser -u agent -- \
        ${pkgs.git}/bin/git --git-dir=/workspace/home/git config core.bare false
      ${pkgs.util-linux}/bin/runuser -u agent -- \
        ${pkgs.git}/bin/git --git-dir=/workspace/home/git config core.worktree /workspace/repo
      ${pkgs.util-linux}/bin/runuser -u agent -- \
        ${pkgs.git}/bin/git --git-dir=/workspace/home/git config user.name "Pi Coding Agent"
      ${pkgs.util-linux}/bin/runuser -u agent -- \
        ${pkgs.git}/bin/git --git-dir=/workspace/home/git config user.email "pij-agent@localhost"
      cp /run/pij/session/auth.json /workspace/home/.pi/agent/auth.json
      cp /run/pij/session/models.json /workspace/home/.pi/agent/models.json
      cp /run/pij/session/settings.json /workspace/home/.pi/agent/settings.json
      chown agent:agent \
        /workspace/home/.pi/agent/auth.json \
        /workspace/home/.pi/agent/models.json \
        /workspace/home/.pi/agent/settings.json
      chmod 0600 \
        /workspace/home/.pi/agent/auth.json \
        /workspace/home/.pi/agent/models.json \
        /workspace/home/.pi/agent/settings.json
      install -d -o root -g root -m 0755 /run/pij
      printf 'gitdir: /workspace/home/git\n' > /run/pij/gitdir
      chown agent:agent /run/pij/gitdir
      chmod 0444 /run/pij/gitdir
      ${pkgs.util-linux}/bin/mount --bind /run/pij/gitdir /workspace/repo/.git
      ${pkgs.util-linux}/bin/runuser -u agent -- \
        ${pkgs.git}/bin/git -C /workspace/repo reset --mixed --quiet "$base_commit"
    '';
  };

  systemd.services.pij-self-test = {
    description = "Exercise the PIJ worktree boundary for the live test";
    wantedBy = [ "multi-user.target" ];
    after = [ "pi-workspace-init.service" ];
    requires = [ "pi-workspace-init.service" ];
    unitConfig.ConditionKernelCommandLine = "pij.selftest";
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      set -euo pipefail
      trap 'printf "pij-self-test failed at line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
      credential_marker_prefix="pij-host-credential-"'marker-'
      scan_guest_processes() {
        local proc_file proc_dir proc_fd proc_text proc_field
        local proc_files=(/proc/[0-9]*/cmdline /proc/[0-9]*/environ)
        for proc_file in "''${proc_files[@]}"; do
          proc_dir=''${proc_file%/*}
          if [[ ! -r $proc_file ]]; then
            if [[ -e $proc_file && -e $proc_dir/exe ]]; then
              printf 'credential marker scan cannot read userspace process state: %s\n' "$proc_file" >&2
              return 1
            fi
            continue
          fi
          if ! exec {proc_fd}<"$proc_file" 2>/dev/null; then
            if [[ -e $proc_file && -e $proc_dir/exe ]]; then
              printf 'credential marker scan could not open process state: %s\n' "$proc_file" >&2
              return 1
            fi
            continue
          fi
          proc_text=
          while IFS= read -r -d "" -u "$proc_fd" proc_field; do
            proc_text+="$proc_field"$'\n'
          done
          exec {proc_fd}<&-
          if [[ "$proc_text" == *"$credential_marker_prefix"* ]]; then
            printf 'credential marker found in guest process state: %s\n' "$proc_file" >&2
            return 1
          fi
        done
      }
      scan_guest_root() {
        local guest_root=$1 guest_file grep_status file_list
        [[ -e $guest_root ]] || return 0
        file_list=$(${pkgs.coreutils}/bin/mktemp)
        ${pkgs.findutils}/bin/find "$guest_root" -xdev -type f -readable -print0 > "$file_list" \
          || { ${pkgs.coreutils}/bin/rm -f -- "$file_list"; return 1; }
        while IFS= read -r -d "" guest_file; do
          if ${pkgs.gnugrep}/bin/grep -a -Fq -- "$credential_marker_prefix" "$guest_file"; then
            printf 'credential marker found in guest file: %s\n' "$guest_file" >&2
            ${pkgs.coreutils}/bin/rm -f -- "$file_list"
            return 1
          else
            grep_status=$?
          fi
          if [[ $grep_status -ne 1 && -e $guest_file ]]; then
            printf 'credential marker scan failed for guest file: %s\n' "$guest_file" >&2
            ${pkgs.coreutils}/bin/rm -f -- "$file_list"
            return 1
          fi
        done < "$file_list"
        ${pkgs.coreutils}/bin/rm -f -- "$file_list"
      }
      scan_guest_state() {
        local guest_root
        if ! scan_guest_processes; then
          echo "guest process credential scan failed" >&2
          return 1
        fi
        for guest_root in \
          / /dev /dev/shm /run /run/pij/session \
          /workspace/repo /workspace/git-objects /workspace/home; do
          if ! scan_guest_root "$guest_root"; then
            printf 'guest filesystem credential scan failed at root: %s\n' "$guest_root" >&2
            return 1
          fi
        done
      }
      scan_guest_state
      test ! -e /home/user
      test ! -e /host
      test ! -e /mnt/host
      blocked_host_port=
      for kernel_parameter in $(< /proc/cmdline); do
        case "$kernel_parameter" in
          pij.blocked_host_port=*) blocked_host_port=''${kernel_parameter#*=} ;;
        esac
      done
      [[ "$blocked_host_port" =~ ^[0-9]+$ ]]
      ${pkgs.iproute2}/bin/ip link set eth0 up
      ${pkgs.iproute2}/bin/ip route replace default via 10.0.2.2 dev eth0
      ${pkgs.util-linux}/bin/runuser -u agent -- env -i \
        HOME=/workspace/home \
        blocked_host_port="$blocked_host_port" \
        PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.git pkgs.jq pkgs.util-linux ]} \
        ${pkgs.bash}/bin/bash -euo pipefail -c '
          cd /workspace/repo
          test "$(findmnt -n -o FSTYPE -T /workspace/repo)" = 9p
          repo_options=$(findmnt -n -o OPTIONS -T /workspace/repo)
          printf "pij-self-test: repo mount options=%s\n" "$repo_options"
          [[ ",$repo_options," == *,rw,* ]]
          [[ ",$repo_options," == *,nodev,* ]]
          [[ ",$repo_options," == *,nosuid,* ]]
          test "$(git rev-parse --show-toplevel)" = /workspace/repo
          test "$(git rev-parse --absolute-git-dir)" = /workspace/home/git
          test "$(git branch --show-current)" = pij-session
          object_options=$(findmnt -n -o OPTIONS -T /workspace/git-objects)
          [[ ",$object_options," == *,ro,* ]]
          printf "written by pij guest\n" > pij-live-test.txt
          git add pij-live-test.txt
          git commit -qm "test: verify pij writable worktree"
          git rev-parse HEAD > pij-live-commit.txt
          printf "corrupted by pij guest\n" > baseline.txt
          rm deletion-target.txt
          test ! -e /workspace/host-secret
          test -z "''${SSH_AUTH_SOCK:-}"
          test -z "''${DBUS_SESSION_BUS_ADDRESS:-}"
          test -z "''${GH_TOKEN:-}"
          test -z "''${GITHUB_TOKEN:-}"
          test ! -e /workspace/home/.ssh
          test ! -e /workspace/home/.config/gh/hosts.yml
          test ! -S /nix/var/nix/daemon-socket/socket
          test ! -S /run/docker.sock
          test ! -S /run/podman/podman.sock
          if timeout 2 bash -c "exec 3<>/dev/tcp/10.0.2.2/$blocked_host_port" 2>/dev/null; then
            echo "restricted guest reached an unforwarded host service" >&2
            exit 1
          fi
          if timeout 2 bash -c "exec 3<>/dev/tcp/1.1.1.1/80" 2>/dev/null; then
            echo "restricted guest reached the public Internet" >&2
            exit 1
          fi
          guest_marker_prefix=pij-host-credential-
          guest_marker_prefix+=marker-
          guest_token=$(jq -r ".\"openai-codex\".access" /workspace/home/.pi/agent/auth.json)
          for request_number in 1 2; do
            printf -v request_body "{\"model\":\"fake-codex\",\"input\":\"pij-live-bridge-%s\"}" "$request_number"
            exec 3<>/dev/tcp/10.0.2.100/8645
            printf "POST /codex/responses HTTP/1.1\r\nHost: bridge\r\nAuthorization: Bearer %s\r\nContent-Type: application/json\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s" \
              "$guest_token" "''${#request_body}" "$request_body" >&3
            bridge_response=$(cat <&3)
            exec 3>&-
            [[ "$bridge_response" == HTTP/1.1\ 200* ]]
            [[ "$bridge_response" == *response.completed* ]]
            [[ "$bridge_response" != *"$guest_marker_prefix"* ]]
          done
        '
      scan_guest_state
      ${piSessionShutdown}/bin/pi-session-shutdown
    '';
  };

  systemd.services."serial-getty@ttyS0" = {
    after = [ "pi-workspace-init.service" ];
    requires = [ "pi-workspace-init.service" ];
    unitConfig.ConditionKernelCommandLine = "!pij.selftest";
    serviceConfig = {
      Restart = lib.mkForce "no";
      ExecStopPost = "${piSessionShutdown}/bin/pi-session-shutdown";
    };
  };

  environment.systemPackages = with pkgs; [
    bashInteractive
    coreutils
    fd
    git
    jq
    piAgent
    ripgrep
  ];

  services.getty.helpLine = ''
    Pi sandbox: the selected host worktree is mounted read-write at /workspace/repo.
    Repository and Git metadata damage is accepted. Exit with Ctrl-D.
    Emergency exit: press Ctrl-a, then x
  '';

  virtualisation = {
    cores = 4;
    memorySize = 4096;
    diskImage = null;
    graphics = false;
    restrictNetwork = true;
    useNixStoreImage = true;
    mountHostNixStore = false;
    useHostCerts = false;
    writableStore = false;
    sharedDirectories = lib.mkForce { };
    qemu = {
      forceAccel = true;
      networkingOptions = lib.mkForce [ "-nic none" ];
    };
  };
}
