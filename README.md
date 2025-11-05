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

You can run, for example, the main testbench with the following command:

```bash
make wave TB=top/top_tachyon_rv_tb
```

Since the top modules are designed to print to an LCD screen, the testbenches
will print characters to the terminal as they would appear on the LCD.

## System specs

### Memory map

The memory map for **data memory** is as follows:

|  Range start  | Size (bytes) |     Description      |
| :-----------: | :----------: | :------------------: |
| `0x0000'0000` |    16384     | Instruction/data RAM |
| `0x2000'0000` |      4       |      TRNG value      |
| `0x4000'0000` |     128      |      Video RAM       |
| `0x6000'0000` |      1       |        Joypad        |
| `0x8000'0000` |      8       |    Video palette     |
| `0xA000'0000` |      1       |     Video on/off     |
| `0xC000'0000` |      2       |         LCD          |
| `0xE000'0000` |      4       |    Audio control     |

LCD section:

|  Range start  | Size (bytes) | Description |
| :-----------: | :----------: | :---------: |
| `0xC000'0000` |      1       |  LCD ctrl   |
| `0xC000'0001` |      1       |  LCD data   |

All memory ranges left unspecified can be assumed to be mirrors of the rest,
though they should not be used.

On the other hand, the **instruction memory** lines are hardwired to RAM and
nothing else, so instructions will never be read from anywhere other than RAM.
