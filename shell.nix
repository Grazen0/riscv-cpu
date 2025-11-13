{
  pkgs ? import <nixpkgs> { },
  riscvPkgs,
}:
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
