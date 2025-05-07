{
  description = "Flake for lazy_test dev environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    gomod2nix = {
      url = "github:tweag/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, gomod2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true; # Allow unfree packages
          overlays = [ gomod2nix.overlays.default ];
        };

        deps = {
          k9s = pkgs.k9s;
          k3d = pkgs.k3d;
          go = pkgs.go;
          gopls = pkgs.gopls;
          go-tools = pkgs.go-tools;
          devspace = pkgs.devspace;
          postgresql_13 = pkgs.postgresql_13;
          nodejs_22 = pkgs.nodejs_22;
          jq = pkgs.jq;
          gomod2nix = pkgs.gomod2nix;
          watchexec = pkgs.watchexec;

          google-cloud-sdk = pkgs.google-cloud-sdk.withExtraComponents
            ([ pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin ]);
          kubectl = pkgs.kubectl;
          lima = pkgs.lima;
          gnugrep = pkgs.gnugrep;
          openssh = pkgs.openssh;
          kubernetes-helm = pkgs.wrapHelm pkgs.kubernetes-helm {
            plugins = [
              pkgs.kubernetes-helmPlugins.helm-diff
              pkgs.kubernetes-helmPlugins.helm-git
            ];
          };
          terraform = pkgs.terraform;
          coreutils = pkgs.coreutils;
          bash = pkgs.bash;
          helmfile = pkgs.helmfile;
          git = pkgs.git;
          gawk = pkgs.gawk;
          
          default = wrapped-installer;
        };

      in {
        packages = deps // { installerDockerImage = installerDockerImage; };
        devShell =
          pkgs.mkShell { packages = pkgs.lib.attrsets.attrValues deps; };
      });
}

