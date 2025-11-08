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

The **data memory** is organized as follows:

|  Range start  | Size (bytes) |      Description      |
| :-----------: | :----------: | :-------------------: |
| `0x0000'0000` |    16384     | Instruction/data RAM  |
| `0x2000'0000` |      4       |      TRNG value       |
| `0x4000'0000` |     128      | Video tile attributes |
| `0x5000'0000` |     128      |    Video tile data    |
| `0x6000'0000` |      3       |    Joypad control     |
| `0x8000'0000` |      32      |  Video palette data   |
| `0xA000'0000` |      1       |     Video control     |
| `0xC000'0000` |      2       |      LCD control      |
| `0xE000'0000` |      4       |     Audio control     |

All memory ranges left unspecified can be assumed to be mirrors of the rest,
though they should not be used.

On the other hand, the **instruction memory** lines are hardwired to RAM and
nothing else, so instructions will never be read from anywhere other than RAM.

#### Joypad control

|  Range start  | Size (bytes) |                     Description                      |
| :-----------: | :----------: | :--------------------------------------------------: |
| `0x6000'0000` |      1       | Read: I2C ready status / Write: Start reading joypad |
| `0x6000'0001` |      1       |  Joypad data status (1 = valid, 0 = not yet valid)   |
| `0x6000'0002` |      1       |                     Joypad data                      |

Any write to `0x6000'0000` signals the NES bridge module to begin reading the
controller's data via I2C. The program must then wait for the _joypad data
status_ to go high, indicating that the joypad data is now available.

#### Video control

|  Range start  | Size (bytes) |           Description            |
| :-----------: | :----------: | :------------------------------: |
| `0xA000'0000` |      1       | Display on/off (on = 1, off = 0) |

#### LCD control

|  Range start  | Size (bytes) |   Description    |
| :-----------: | :----------: | :--------------: |
| `0xC000'0000` |      1       | LCD instr/status |
| `0xC000'0001` |      1       |     LCD data     |

#### Audio control

|  Range start  | Size (bytes) |   Description    |
| :-----------: | :----------: | :--------------: |
| `0xE000'0000` |      4       | Wave half period |

### Graphics

The video unit produces VGA output in 800x600 @ 72 Hz mode. The screen is
divided in 28x18 square tiles of 32x32 each (although only 25 of a line's tiles
are visible).

Each tile is defined by a byte in the **tile attributes** section
of video memory as follows:

|   7    |   6    |     5 - 4     |      3 - 0      |
| :----: | :----: | :-----------: | :-------------: |
| Y flip | X flip | Color palette | Tile data index |

Therefore, a tile:

- Can be flipped horizontally and/or vertically. Can use 1 of 4 possible color
  palettes programable via the **palette data** memory.
- Renders as one of 16 possible 8x8 tile "images" programmable via the **tile
  data** memory. The format for pixel data is exactly the same as the [Game
  Boy's](https://gbdev.io/pandocs/Tile_Data.html#data-format) tile data format.
