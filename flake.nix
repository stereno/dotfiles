{
  description = "My NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, herdr, ... }@inputs:
  let
    overlays = [ herdr.overlays.default ];

    piSandboxSystem = "x86_64-linux";
    piSandboxPkgs = import nixpkgs {
      system = piSandboxSystem;
      inherit overlays;
      config.allowUnfree = true;
    };
    piAgent = piSandboxPkgs.pi-coding-agent.overrideAttrs (finalAttrs: previousAttrs: {
      version = "0.85.1";
      src = piSandboxPkgs.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${finalAttrs.version}";
        hash = "sha256-gU8BSiqqOYt2RRuQONHHGvZeSM5KFQVrwif9bmuUXUc=";
      };
      npmDepsHash = "sha256-jzlsZIQzfl1FCZZ5//dHFWwMfBZQ4nRD6KB4HHifPqE=";
      npmDeps = piSandboxPkgs.fetchNpmDeps {
        src = finalAttrs.src;
        hash = finalAttrs.npmDepsHash;
      };
      modelData = piSandboxPkgs.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
        hash = "sha256-r30RmGF5RFzm/oizfVfeIvgjwP/TplyuMcVVt/XpklM=";
      };
      preConfigure = ''
        mkdir -p packages/ai/src/providers/data
        tar --extract --gzip --file=${finalAttrs.modelData} \
          --directory=packages/ai/src/providers/data \
          --strip-components=4 \
          package/dist/providers/data
      '';
      buildPhase = ''
        runHook preBuild
        npx tsgo -p packages/chord/tsconfig.build.json
        npx tsgo -p packages/tui/tsconfig.build.json
        npx tsgo -p packages/telemetry/tsconfig.build.json
        npx tsgo -p packages/ai/tsconfig.build.json
        npx tsgo -p packages/agent/tsconfig.build.json
        npx tsgo -p packages/protocol/tsconfig.build.json
        npx tsgo -p packages/client/tsconfig.build.json
        npx tsgo -p packages/server/tsconfig.build.json
        npm run build --workspace=packages/coding-agent
        runHook postBuild
      '';
      postInstall = ''
        local nm="$out/lib/node_modules/pi-monorepo/node_modules"
        for ws in @earendil-works/chord:packages/chord \
                  @earendil-works/pi-ai:packages/ai \
                  @earendil-works/pi-agent-core:packages/agent \
                  @earendil-works/pi-client:packages/client \
                  @earendil-works/pi-protocol:packages/protocol \
                  @earendil-works/pi-telemetry:packages/telemetry \
                  @earendil-works/pi-tui:packages/tui; do
          IFS=: read -r pkg src <<< "$ws"
          rm "$nm/$pkg"
          cp -r "$src" "$nm/$pkg"
        done
        find "$nm" -type l -lname '*/packages/*' -delete
        find "$nm/.bin" -xtype l -delete
      '';
    });
    piModels = {
      main = {
        provider = "openai-codex";
        model = "gpt-5.6-terra";
        thinking = "medium";
      };
    };
    piSandbox = nixpkgs.lib.nixosSystem {
      system = piSandboxSystem;
      specialArgs = { inherit piAgent piModels; };
      modules = [
        "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
        ./system/pi-sandbox/guest.nix
      ];
    };
    pij = piSandboxPkgs.callPackage ./packages/pij {
      inherit piAgent;
      vmRunner = piSandbox.config.system.build.vm;
      piAgentVersion = piAgent.version;
    };
    pijFakeHerdr = piSandboxPkgs.writeShellApplication {
      name = "herdr";
      text = ''
        [ -n "''${PIJ_FAKE_HERDR_DRIVER:-}" ] || {
          printf 'fake Herdr driver is not configured\n' >&2
          exit 2
        }
        exec "$PIJ_FAKE_HERDR_DRIVER" "$@"
      '';
    };
    pijHandoffFaultInjector = piSandboxPkgs.writeShellApplication {
      name = "pij-handoff-fault-injector";
      text = ''
        [ "''${PIJ_FAKE_HANDOFF_FAULT:-}" != "$1" ]
      '';
    };
    pijHerdrTest = pij.override {
      herdr = pijFakeHerdr;
      handoffFaultInjector = pijHandoffFaultInjector;
    };

    mkHome = system: modules: home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };
      extraSpecialArgs = { inherit inputs; };
      modules = modules;
    };
  in
  {
    nixosConfigurations.dev = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs pij; };
      modules = [
        ./hosts/dev
        ./system
        home-manager.nixosModules.home-manager
        {
          nixpkgs.overlays = overlays;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "bak";
          home-manager.overwriteBackup = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
          home-manager.users.user = import ./home;
        }
      ];
    };

    packages.${piSandboxSystem} = {
      inherit pij;
      pi-coding-agent = piAgent;
      pi-sandbox-vm = piSandbox.config.system.build.vm;
    };

    checks.${piSandboxSystem}.pij = piSandboxPkgs.runCommand "pij-check" {
      nativeBuildInputs = [
        pij
        piSandboxPkgs.coreutils
        piSandboxPkgs.git
        piSandboxPkgs.gnugrep
        piSandboxPkgs.python3
        piSandboxPkgs.util-linux
      ];
    } ''
      PIJ_BIN=${pij}/bin/pij \
        PIJ_HERDR_TEST_BIN=${pijHerdrTest}/bin/pij \
        PI_AGENT=${piAgent} \
        PI_SESSION_SHELL=${piSandbox.config.users.users.agent.shell}/bin/pi-session-shell \
        VM_RUNNER=${piSandbox.config.system.build.vm}/bin/run-pi-sandbox-vm \
        GUEST_CONFIG=${./system/pi-sandbox/guest.nix} \
        ${piSandboxPkgs.bash}/bin/bash ${./tests/pij.sh}
      PIJ_BIN=${pij}/bin/pij \
        ${piSandboxPkgs.bash}/bin/bash ${./tests/pij-openai-auth.sh}
      RELAY=${./packages/pij/model-relay.py} \
        PYTHON=${piSandboxPkgs.python3}/bin/python3 \
        ${piSandboxPkgs.python3}/bin/python3 ${./tests/pij-relay.py}
      touch $out
    '';

    homeConfigurations = {
      core = mkHome "x86_64-linux" [
        ./home/core.nix
      ];
      desktop = mkHome "x86_64-linux" [
        plasma-manager.homeModules.plasma-manager
        ./home/desktop.nix
      ];
    };
  };
}
