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
      url = "github:ogulcancelik/herdr";
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
