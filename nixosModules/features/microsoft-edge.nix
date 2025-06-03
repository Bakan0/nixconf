# nixosModules/features/microsoft-edge.nix
{ config, pkgs, ... }:

{
  config = {
    environment.systemPackages = [ pkgs.pinnedPkgs.microsoft-edge ];
  };
}

