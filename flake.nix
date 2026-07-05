{
  description = "Mentat — Token-efficient EDA agent for OpenCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          default = self.packages.${system}.mentat;
          mentat = pkgs.stdenv.mkDerivation {
            pname = "mentat";
            version = "0.1.0";
            src = self;
            installPhase = ''
              mkdir -p $out/share/mentat
              cp SKILL.md $out/share/mentat/
              cp -r scripts $out/share/mentat/
              chmod +x $out/share/mentat/scripts/*
              mkdir -p $out/bin
              for s in $out/share/mentat/scripts/*; do
                ln -s "$s" "$out/bin/$(basename "$s")"
              done
            '';
            meta = with pkgs.lib; {
              description = "Token-efficient EDA agent for OpenCode";
              license = licenses.mit;
            };
          };
        };
      }
    );
}
