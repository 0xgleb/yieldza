{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    foundry.url = "github:shazow/foundry.nix/monthly";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      systems,
      fenix,
      foundry,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ foundry.overlay ];
          };
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              {
                # https://devenv.sh/reference/options/
                packages = with pkgs; [
                  cargo-watch
                  foundry-bin
                  solc
                ];

                languages = {
                  rust = {
                    enable = true;
                    channel = "stable";
                    toolchain = fenix.packages.${pkgs.system}.latest;
                  };
                  python = {
                    enable = true;
                    venv = {
                      enable = true;
                      requirements = builtins.readFile ./requirements.txt;
                      quiet = true;
                    };
                  };
                };

                difftastic.enable = true;
                dotenv.disableHint = true;
              }
            ];
          };
        }
      );
    };
}
