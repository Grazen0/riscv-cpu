{
  pkgs ? import <nixpkgs> { },
}:
let
  riscvPkgs = import <nixpkgs> {
    crossSystem = {
      config = "riscv32-none-elf";
      libc = "newlib-nano";
      abi = "ilp32";
      gcc = {
        arch = "rv32i";
        abi = "ilp32";
      };
    };
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
    riscvPkgs.newlib-nano
  ];
}
