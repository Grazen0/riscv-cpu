# RISC-V CPU

An implementation in Verilog of the RISC-V CPUs designed in "Digital Design and
Computer Architecture: RISC-V Edition" by Sarah L. Harris and David Harris. This
repo includes the single-cycle, multi-cycle and pipelined processors shown in
the book.

## Usage

The designs are located at `src/`, testbenches are at `tb/` and some firmware
code written in C is located at `firmware/`.

You may follow the build instructions to run the testbenches.

## Building

You'll need the following dependencies:

- [GNU Make](https://www.gnu.org/software/make/)
- [Icarus Verilog](https://steveicarus.github.io/)
- [GTKWave](https://gtkwave.sourceforge.net/)
- xxd
- `riscv32-none-elf-gcc` and friends (the [GNU Toolchain for RISC-V](https://github.com/riscv-collab/riscv-gnu-toolchain))

You can run, for example, the testbench for the pipelined CPU with the following
command:

```bash
make wave TB=top/top_pl_tb
```

Since the top modules are designed to print to an LCD screen, the testbenches
will print characters to the terminal as they would appear on the LCD.

## System specs

This system is expected to run under a 100 MHz clock.

### Memory map

The memory map for **data memory** is as follows:

|        Address range        |  Description  | Size (bytes) |
| :-------------------------: | :-----------: | :----------: |
| `0x0000_0000 - 0x0000_1000` |  Program ROM  |     4096     |
| `0x8000_0000 - 0x8000_0200` |   Work RAM    |     1024     |
| `0xC000_0000 - 0xC000_0008` | Video palette |      8       |
| `0xD000_0000 - 0xD000_0080` |   Video RAM   |     128      |
|        `0xE000'0000`        |   LCD ctrl    |      1       |
|        `0xE000'0001`        |   LCD data    |      1       |

All memory ranges left unspecified can be assumed to be mirrors of the rest,
though they should not be used.

On the other hand, the **instruction memory** lines are hardwired to the program
ROM and nothing else, so instructions will never be read from anywhere other
than ROM data.
