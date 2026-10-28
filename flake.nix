{
  description = "Kuna agent-first decompiler, built from source with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/31ecbaca1bdefa45dffc409f0250bd8039ea0010";

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
      devShells = forAllSystems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        fixtureClang = pkgs.callPackage ./nix/fixture-clang.nix {
          clang = pkgs.llvmPackages_18.clang;
          lld = pkgs.llvmPackages_18.lld;
          mingw32Binutils = pkgs.pkgsCross.mingw32.buildPackages.binutils;
          mingw64Binutils = pkgs.pkgsCross.mingwW64.buildPackages.binutils;
        };
      in {
        default = pkgs.mkShell {
          # CLI tests build and execute C/Fortran fixtures inside Cargo's
          # Nix runtime environment; native drivers must use the matching loader.
          packages = [ pkgs.cargo pkgs.rustc pkgs.clippy pkgs.rustfmt pkgs.python3 pkgs.gnumake pkgs.git ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ fixtureClang pkgs.gfortran ];
          hardeningDisable = [ "fortify" "fortify3" "zerocallusedregs" ];
          CARGO_BUILD_JOBS = "2";
          CARGO_INCREMENTAL = "0";
          CARGO_PROFILE_DEV_DEBUG = "0";
          CARGO_PROFILE_TEST_DEBUG = "0";
          shellHook = ''
            # Host fixture compilers must not link Nix libraries with the host loader.
            # GUI launchers can also inject their own runtime library path.
            unset LD_LIBRARY_PATH LIBRARY_PATH NIX_CFLAGS_LINK
          '' + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            # DWARF fixture relocations are interpreted before decompression by
            # the current loader. Keep full -g information in its plain format.
            export NIX_CFLAGS_COMPILE="''${NIX_CFLAGS_COMPILE-} -gz=none"
          '';
        };
      });
      nixosModules = { kuna = module; default = module; };
      darwinModules = { kuna = module; default = module; };
    };
}
