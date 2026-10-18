{
  description = "Kuna agent-first decompiler, built from source with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      module = { config, lib, pkgs, ... }: {
        options.programs.kuna = {
          enable = lib.mkEnableOption "the Kuna decompiler and its agent skill";
          package = lib.mkOption {
            type = lib.types.package;
            default = self.packages.${pkgs.stdenv.hostPlatform.system}.kuna;
            defaultText = lib.literalExpression "inputs.kuna.packages.\${pkgs.system}.kuna";
            description = "Kuna package to install.";
          };
        };
        config = lib.mkIf config.programs.kuna.enable {
          environment.systemPackages = [ config.programs.kuna.package ];
        };
      };
    in {
      packages = forAllSystems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        kuna = pkgs.callPackage ./nix/package.nix { };
      in { inherit kuna; default = kuna; });
      apps = forAllSystems (system: {
        default = { type = "app"; program = "${self.packages.${system}.kuna}/bin/kuna"; };
        kuna = self.apps.${system}.default;
      });
      checks = forAllSystems (system: { inherit (self.packages.${system}) kuna; });
      devShells = forAllSystems (system: let pkgs = nixpkgs.legacyPackages.${system}; in {
        default = pkgs.mkShell {
          packages = [ pkgs.cargo pkgs.rustc pkgs.clippy pkgs.rustfmt pkgs.python3 pkgs.gnumake pkgs.git ];
          hardeningDisable = [ "fortify" "fortify3" "zerocallusedregs" ];
          CARGO_BUILD_JOBS = "2";
          CARGO_INCREMENTAL = "0";
          CARGO_PROFILE_DEV_DEBUG = "0";
          CARGO_PROFILE_TEST_DEBUG = "0";
          shellHook = ''
            # GUI launchers can inject bundled libraries and host link paths.
            unset LD_LIBRARY_PATH NIX_CFLAGS_LINK
          '';
        };
      });
      nixosModules = { kuna = module; default = module; };
      darwinModules = { kuna = module; default = module; };
    };
}
