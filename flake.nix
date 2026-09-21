{
  description = "gitutils.nvim";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      perSystem =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          gitutils-nvim = pkgs.vimUtils.buildVimPlugin {
            name = "gitutils.nvim";
            src = ./.;
          };

          wrappedNvim = pkgs.callPackage ./nix/nvim.nix {
            inherit gitutils-nvim;
          };

        in
        {
          packages = {
            default = gitutils-nvim;
            nvim = wrappedNvim;
          };
          apps.nvim = {
            type = "app";
            program = "${wrappedNvim}/bin/nvim";
          };
        };

    in
    {
      packages = forAllSystems (system: (perSystem system).packages);
      apps = forAllSystems (system: (perSystem system).apps);
    };
}
