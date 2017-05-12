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
	DB	0
blkcnt:	DW	RESVD_SECTORS - 1 ; Read the rest of the reserved sectors
db_add:	DD	0x7E00
d_lba:	DQ	1

stage0:
	xor	ax, ax ; zero all the things!
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	
	mov si, DskAdrPkt
	mov ah, 0x42
	int 0x13 ; note that dl is already set to the drive number
	
	jmp stage1 ; TODO: check for disk read errors

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
	
	; enable A20 via keyboard controller
	mov al, 0xdd
	out 0x64, al
	
	mov	si, msg
	mov	ah, 0x0e
.loop	lodsb
	or	al, al
	jz	halt
	int	0x10
	jmp	.loop

halt:	CLI
	HLT

msg:	DB "stage1 bootloader has been loaded!", 0

; padding + FAT ;

	TIMES RESVD_SECTORS*SECTOR_SIZE-($-$$) DB 0
	DD 0x0ffffff0
	DD 0x0fffffff
	DD 0x0fffffff

; padding (rest of filesytem) ;

	TIMES 0x100000-($-$$) DB 0 ; Only pad to 1MB, NASM is slow at padding :(
