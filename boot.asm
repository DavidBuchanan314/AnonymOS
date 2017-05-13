	BITS 16
	ORG 0x7c00

; constants ;

	IMAGE_SIZE	EQU 0x8000000 ; 128MiB
	SECTOR_SIZE	EQU 0x200
	RESVD_SECTORS	EQU 32
	IMAGE_SECTORS	EQU IMAGE_SIZE / SECTOR_SIZE
	FAT_SECTORS	EQU IMAGE_SECTORS / SECTOR_SIZE * 4 ; ???

; jump to stage0 bootloader ;

	jmp stage0
	nop

; FAT32 Parameter Block ;

	BS_OEMName:	DB "AnonymOS"
	BPB_BytsPerSec:	DW SECTOR_SIZE
	BPB_SecPerClus:	DB 1
	BPB_RsvdSecCnt:	DW 32
	BPB_NumFATs:	DB 1
	BPB_RootEntCnt:	DW 0
	BPB_TotSec16:	DW 0
	BPB_Media:	DB 0xF8
	BPB_FATSz16:	DW 0
	BPB_SecPerTrk:	DW 0x20 ; ???
	BPB_NumHeads:	DW 0x40 ; ???
	BPB_HiddSec:	DD 0
	BPB_TotSec32:	DD IMAGE_SECTORS
	BPB_FATSz32:	DD FAT_SECTORS
	BPB_ExtFlags:	DW 0
	BPB_FSVer:	DW 0
	BPB_RootClus:	DD 2
	BPB_FSInfo:	DW 1
	BPB_BkBootSec:	DW 0 ; I like to live on the edge
	BPB_Reserved:	TIMES 12 DB 0
	BS_DrvNum:	DB 0x80 ; ???
	BS_Reserved1:	DB 0
	BS_BootSig:	DB 0x29
	BS_VolID:	DD __POSIX_TIME__
	BS_VolLab:	DB "NO NAME    "
	BS_FilSysType:	DB "FAT     "

; stage0 bootloader code ;

	ALIGN	4 ; needed for Disk Address Packet

DskAdrPkt:
	DB	0x10 ; packet length
	DB	0 ; reserved
blkcnt:	DW	RESVD_SECTORS - 1 ; Read the rest of the reserved sectors
db_add:	DD	0x7E00
d_lba:	DQ	1

drvnum:
	DB	0

stage0:
	cli
	xor	ax, ax ; zero all the things!
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ah, 0x70
	mov	ss, ax
	mov	sp, 0xffff ; set up a 64k stack from 0x7ffff down to 0x70000
	sti
	
	mov	[drvnum], dl ; Back up the drive number
	
	mov	si, .msg
	call	puts
	
	mov	si, DskAdrPkt
	mov	ah, 0x42
	mov	dl, [drvnum]
	int	0x13
	
	jnc	stage1
	jmp	diskerr
	
.msg	DB `stage0 bootloader loaded.\r\n`, 0

diskerr:
	mov	si, .error
	call	puts
	jmp	halt
	
.error	DB `A disk read error occured.\r\n`, 0

puts: ; string in si
	mov	ah, 0x0e
.loop	lodsb
	or	al, al
	jz	.done
	int	0x10
	jmp	.loop
.done	ret

halt:
	cli
	hlt

	TIMES 510-($-$$) DB 0
	DW 0xAA55		; boot signature

; FSInfo sector ;

	FSI_LeadSig:	DD 0x41615252
	FSI_Reserved1:	TIMES 480 DB 0
	FSI_StrucSig:	DD 0x61417272
	FSI_Free_Count:	DD IMAGE_SECTORS - RESVD_SECTORS - FAT_SECTORS - 1
	FSI_Nxt_Free:	DD 2
	FSI_Reserved2:	TIMES 12 DB 0
	FSI_TrailSig:	DD 0xaa550000

; stage1 bootloader code ;

stage1:
	
	mov	si, .msg
	call	puts
	
	; enable A20 via keyboard controller
	mov	al, 0xdd
	out	0x64, al
	
	mov	eax, RESVD_SECTORS + FAT_SECTORS
	call	loadsect
	
	call scandir
	
	jmp	halt

.msg:	DB `stage1 bootloader loaded.\r\n`, 0

loadsect: ; loads sector number eax at offset 0xc000
	mov	[.lba], eax
	mov	si, .pkt
	mov	ah, 0x42
	mov	dl, [drvnum]
	int	0x13
	jc	diskerr
	ret
	ALIGN	4 ; needed for following Disk Address Packet
.pkt	DB	0x10
	DB	0
	DW	1
	DD	0xc000
.lba	DQ	0


; scan a FAT32 cluster at 0xc000 for the kernel.
; eax = kernel cluster on success
; eax = 0 on failure
scandir:
	mov	bx, 0xc000
.loop	mov	si, bx
	mov	di, .fname
	mov	cx, 11
	repe cmpsb
	je 	.success
	add	bx, 32
	cmp	bx, 0xe000
	jl	.loop
	xor	eax, eax
	ret
.success:
	push	bx
	mov	si, .msg
	call	puts
	pop	bx
	mov	ax, [bx+20]
	shl	eax, 16
	mov	ax, [bx+26]
	add	al, '0'
	mov	ah, 0x0e
	int	0x10
	ret

.msg:	DB `Found kernel directory entry.\r\n`, 0
.fname:	DB "KERNEL  BIN"

; padding + FAT ;

	TIMES RESVD_SECTORS*SECTOR_SIZE-($-$$) DB 0
fat:	DD 0x0ffffff0
	DD 0x0fffffff
	DD 0x0fffffff

; padding (rest of filesytem) ;

	TIMES 0x100000-($-$$) DB 0 ; Only pad to 1MB, NASM is slow at padding :(
