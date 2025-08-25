{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./yaml.nix
    ./bash.nix
    ./powershell.nix
    ./python.nix
    ./terraform.nix
    ./elixir.nix
  ];
}
