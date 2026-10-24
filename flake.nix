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
      inputs.rust-overlay.follows = "rust-overlay";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.uv2nix.follows = "uv2nix";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      plasma-manager,
      herdr,
      git-hooks,
      ...
    }@inputs:
    let
      overlays = [ herdr.overlays.default ];

      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      preCommit = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          gitleaks.enable = true;
          detect-private-keys.enable = true;
          nixfmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;
        };
      };

      mkHome =
        system: modules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
          extraSpecialArgs = { inherit inputs; };
          inherit modules;
        };
    in
    {
      checks.${system} = {
        pre-commit = preCommit;
        # The gitleaks hook scans only staged changes, which are empty inside
        # the check sandbox, so scan the whole source tree here.
        gitleaks = pkgs.runCommand "gitleaks" { } ''
          ${pkgs.lib.getExe pkgs.gitleaks} dir --no-banner --redact --verbose ${./.}
          touch $out
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        inherit (preCommit) shellHook;
        packages = preCommit.enabledPackages;
      };

      formatter.${system} = pkgs.nixfmt-tree;

      nixosConfigurations.dev = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
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
