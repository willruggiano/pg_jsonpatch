{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    process-compose.url = "github:Platonic-Systems/process-compose-flake";
    services.url = "github:juspay/services-flake";
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://willruggiano.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "willruggiano.cachix.org-1:rz00ME8/uQfWe+tN3njwK5vc7P8GLWu9qbAjjJbLoSw="
    ];
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.process-compose.flakeModule
      ];
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {
        config,
        self',
        inputs',
        lib,
        pkgs,
        system,
        ...
      }: {
        devShells.default = pkgs.mkShell {
          name = "pg_jsonpatch";
          buildInputs = with pkgs; [
            postgresql
            perlPackages.TAPParserSourceHandlerpgTAP # pg_prove
          ];
          PGDATA = "data/default";
          PGHOST = "localhost";
          PGDATABASE = "postgres";
        };

        packages = {
          default = pkgs.callPackage ./package.nix {inherit (pkgs) postgresql;};
          v17 = pkgs.callPackage ./package.nix {postgresql = pkgs.postgresql_17;};
          v16 = pkgs.callPackage ./package.nix {postgresql = pkgs.postgresql_16;};
          v15 = pkgs.callPackage ./package.nix {postgresql = pkgs.postgresql_15;};
          v14 = pkgs.callPackage ./package.nix {postgresql = pkgs.postgresql_14;};
        };

        process-compose.devenv = {
          imports = [
            inputs.services.processComposeModules.default
          ];

          cli.options.no-server = false;

          services.postgres.default = {
            enable = true;
            extensions = exts:
              with exts; [
                config.packages.default
                pgtap
              ];
            initialScript.after = ''
              create extension pgtap;
            '';
            package = config.packages.default.postgresql;
            settings = {
              log_statement = "all";
              logging_collector = false;
            };
          };
        };
      };
    };
}
