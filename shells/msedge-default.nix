# shell.nix
{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

pkgs.mkShell {
  buildInputs = [
    pkgs.microsoft-edge
  ];

  shellHook = ''
    export BROWSER="${pkgs.microsoft-edge}/bin/microsoft-edge"
  '';
}

