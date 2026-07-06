{
  description = "Mentat — Token-efficient EDA agent for OpenCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      homeManagerModules = {
        mentat = import ./modules/home-manager.nix;
      };
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          default = self.packages.${system}.mentat;
          mentat = pkgs.stdenv.mkDerivation {
            pname = "mentat";
            version = "0.2.0";
            src = self;
            buildInputs = [ pkgs.jq ];
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
              runtimeDependencies = [ pkgs.jq pkgs.duckdb pkgs.gnuplot ];
            };
          };
        };
      }
    );
}
