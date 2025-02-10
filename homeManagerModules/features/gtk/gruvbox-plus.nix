{pkgs}: let
  link = "https://github.com/SylEleuth/gruvbox-plus-icon-pack/releases/download/v6.1.1/gruvbox-plus-icon-pack-6.1.1.zip";
in
  pkgs.stdenv.mkDerivation {
    name = "gruvbox-plus";

    src = pkgs.fetchurl {
      url = link;
      sha256 = "14h8gylcifyny68jhhzqrx4biakhizzfn54dsxz5w03jmfp71ii6";
    };

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out
      ${pkgs.unzip}/bin/unzip $src -d $out/
    '';

    postFixup = ''
      # Remove dangling symlinks
      find $out -xtype l -delete
    '';
  }
