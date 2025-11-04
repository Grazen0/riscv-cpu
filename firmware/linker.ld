ENTRY(_start)

MEMORY {
  DATA (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS {
  .text : {
    KEEP(*(.text._start))
    *(.text)
    *(.text.*)
    *(.rodata) 
    *(.rodata.*) 
    KEEP(*(.init))
    KEEP(*(.fini))

    . = ALIGN(4);
    _etext = .;
  } > DATA

  _sidata = LOADADDR(.data);

  .data : {
    . = ALIGN(4);
    _sdata = .;

    *(.data)
    *(.data.*)
    KEEP(*(.init_array))
    KEEP(*(.fini_array))

    . = ALIGN(4);
    _edata = .;
  } > DATA
  
  .sdata : {
    . = ALIGN(4);

    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.* .gnu.linkonce.s.*)

    . = ALIGN(4);
  } > DATA

  .bss : {
    . = ALIGN(4);
    _sbss = .;
    __bss_start = _sbss;

    *(.bss)
    *(.bss.*)
    *(.sbss)
    *(.sbss.*)
    *(COMMON)

    . = ALIGN(4);
    _ebss = .;
    __bss_end = _ebss;
  } > DATA

  _end = .;
  __stack_top = ORIGIN(DATA) + LENGTH(DATA);
}
