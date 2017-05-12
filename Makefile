all: boot.bin

boot.bin: boot.asm
	nasm -f bin -o boot.bin boot.asm
	dd if=/dev/zero bs=127M count=1 >> boot.bin 2>/dev/null # padding

test: all
	qemu-system-i386 -drive format=raw,file=boot.bin
