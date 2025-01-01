{
  description = "JM&Clan NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    xremap-flake.url = "github:xremap/nix-flake";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    hyprland.url = "github:hyprwm/Hyprland"; 

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    stylix.url = "github:danth/stylix/ed91a20c84a80a525780dcb5ea3387dddf6cd2de";

    persist-retro.url = "github:Geometer1729/persist-retro";

    #  woomer = {
    #    url = "github:coffeeispower/woomer";
    #    inputs.nixpkgs.follows = "nixpkgs";
    #  };
  };

      outputs = {...} @ inputs: let
    # super simple boilerplate-reducing
    # lib with a bunch of functions
    myLib = import ./myLib/default.nix {inherit inputs;};
  in
    with myLib; {
      nixosConfigurations = {
        # ===================== NixOS Configurations ===================== #

        acc01ade = mkSystem ./hosts/acc01ade/configuration.nix;
        # nighthawk = mkSystem ./hosts/nighthawk/configuration.nix;
        tyr = mkSystem ./hosts/tyr/configuration.nix;
        # liveiso = mkSystem ./hosts/liveiso/configuration.nix;
      };

      homeConfigurations = {
        # ================ Maintained home configurations ================ #

        "emet@acc01ade" = mkHome "x86_64-linux" ./hosts/acc01ade/home.nix;
        # "emet@nighthawk" = mkHome "x86_64-linux" ./hosts/nighthawk/home.nix;
        "emet@tyr" = mkHome "x86_64-linux" ./hosts/tyr/home.nix;

      };

      homeManagerModules.default = ./homeManagerModules;
      nixosModules.default = ./nixosModules;
    };
}
