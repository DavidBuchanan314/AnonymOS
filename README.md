# AnonymOS
Yet another unnamed operating system project. The OS itself does not offer anonymity
(or any other useful features), I simply couldn't think of a name.

![AnonymOS Screenshot](https://github.com/DavidBuchanan314/AnonymOS/raw/master/misc/screenshot.png)

## Goals

- The multi-stage bootloader will capable of loading a 32-bit kernel in protected mode from a FAT32 filesystem.
- The kernel will be written in C.
- The kernel will have basic filesystem and multitasking support.
- Port an existing C compiler to the OS, so that it can be self-hosting (This is unlikely to ever happen).

## Current Status

- A bootable FAT32 disk image is generated.
- the bootloader is capable of loading and executing a 32-bit kernel (written in C). Currently, the loadable kernel
size is limited by the 1MB memory barrier. The bootloader also sets up VESA graphics.

## Building

Running `make` will generate a bootable FAT32 disk image called `boot.bin`. You can test
this image in QEMU by running `make test`, or possibly by writing it to a USB drive.

`i686-elf-gcc` is required to compile the kernel.
