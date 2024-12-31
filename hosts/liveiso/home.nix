{
  inputs,
  outputs,
  pkgs,
  lib,
  ...
}: {
  myHomeManager = {
    bundles.general.enable = true;
  };

  home = {
    stateVersion = "24.11";
    homeDirectory = lib.mkDefault "/home/emet";
    username = "emet";

    packages = with pkgs; [];
  };
}
