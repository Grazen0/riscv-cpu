{
  pkgs ? import <nixpkgs> { },
}:
let
  riscvPkgs = import <nixpkgs> {
    crossSystem.config = "riscv32-none-elf";
  };
in
pkgs.mkShell {
  hardeningDisable = [
    "relro"
    "bindnow"
  ];

  packages = with pkgs; [
    bear
    glibc_multi
    gtkwave
    iverilog
    xxd

    riscvPkgs.buildPackages.binutils
    riscvPkgs.buildPackages.gcc
  ];
}
