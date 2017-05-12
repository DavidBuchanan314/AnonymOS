all: boot.bin
	echo "Copying rootfs files to disk image. Root will be required for loopback mount."
	mkdir -p mnt
	sudo mount boot.bin mnt/ -o umask=000
	cp -r rootfs/* mnt/
	sudo umount mnt/

boot.bin: boot.asm
	nasm -f bin -o boot.bin boot.asm
	dd if=/dev/zero bs=127M count=1 >> boot.bin 2>/dev/null # padding

test: all
	qemu-system-i386 -drive format=raw,file=boot.bin
