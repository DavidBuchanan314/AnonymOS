VPATH=kernel/:bootloader/:rootfs/

.PHONY: all test

all: boot.bin

boot.bin: boot.asm KERNEL.BIN
	nasm -f bin -o boot.bin -l boot.lst bootloader/boot.asm
	dd if=/dev/zero bs=127M count=1 >> boot.bin 2>/dev/null # padding
	echo "Copying rootfs files to disk image. Root will be required for loopback mount."
	mkdir -p mnt
	sudo mount boot.bin mnt/ -o umask=000
	# fill filesytem with some garbage to test the fs code better
	for i in {1..50} ; do \
		echo foobar > "mnt/JUNK$$i.BIN" ;\
	done
	cp -r rootfs/* mnt/
	sudo umount mnt/

#KERNEL.BIN: kernel.asm rootfs
#	nasm -f bin -o rootfs/KERNEL.BIN kernel/kernel.asm

KERNEL.BIN: kernel.c rootfs
	i686-elf-gcc -o rootfs/KERNEL.BIN kernel/kernel.c -ffreestanding -Ofast -nostdlib -Wl,--oformat=binary,-Ttext=0x10000 -Wall -Wextra -Wpedantic

rootfs:
	mkdir -p rootfs

test: boot.bin
	qemu-system-i386 -m 512M -drive format=raw,file=boot.bin -serial stdio
