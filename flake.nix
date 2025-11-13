{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=2fb006b87f04c4d3bdf08cfdbc7fab9c13d94a15";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      perSystem =
        {
          self',
          pkgs,
          system,
          ...
        }:
        let
          riscvPkgs = import nixpkgs {
            inherit system;
            crossSystem = {
              config = "riscv32-none-elf";
              libc = "newlib-nano";
              gcc.arch = "rv32i";
            };
          };
        in
        {
          devShells.default = pkgs.callPackage ./shell.nix { inherit riscvPkgs; };
        };
    };
}
