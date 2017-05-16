all: boot.bin

boot.bin: bootloader/boot.asm KERNEL.BIN
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

KERNEL.BIN: kernel/kernel.asm rootfs
	nasm -f bin -o rootfs/KERNEL.BIN kernel/kernel.asm

rootfs:
	mkdir -p rootfs

test: boot.bin
	qemu-system-i386 -drive format=raw,file=boot.bin
