	BITS	16
	ORG	0x7C00

; constants ;

	IMAGE_SIZE	EQU 0x8000000 ; 128MiB
	SECTOR_SIZE	EQU 0x200
	RESVD_SECTORS	EQU 32
	IMAGE_SECTORS	EQU IMAGE_SIZE / SECTOR_SIZE
	FAT_SECTORS	EQU IMAGE_SECTORS / SECTOR_SIZE * 4 ; ???

; jump to stage0 bootloader ;

	jmp	stage0
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
	DW	RESVD_SECTORS - 1 ; Read the rest of the reserved sectors
	DD	0x7E00
	DQ	1

drvnum:
	DB	0

cluster:
	DD	2

stage0:
	cld ; clear the direction flag, might be a good idea
	
	cli
	xor	ax, ax ; zero all the things!
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ah, 0x70
	mov	ss, ax
	mov	sp, 0xFFFF ; set up a 64k stack from 0x7ffff down to 0x70000
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
	mov	ah, 0x0E
.loop	lodsb
	or	al, al
	jz	.done
	int	0x10
	jmp	.loop
.done	ret

halt:
	cli
	hlt

	TIMES	510-($-$$) DB 0
	DW	0xAA55		; boot signature

; FSInfo sector ;

	FSI_LeadSig:	DD 0x41615252
	FSI_Reserved1:	TIMES 480 DB 0
	FSI_StrucSig:	DD 0x61417272
	FSI_Free_Count:	DD IMAGE_SECTORS - RESVD_SECTORS - FAT_SECTORS - 1
	FSI_Nxt_Free:	DD 2
	FSI_Reserved2:	TIMES 12 DB 0
	FSI_TrailSig:	DD 0xAA550000

; stage1 bootloader code ;

stage1:
	
	mov	si, .msg
	call	puts
	
	; enable A20 via FAST A20
	in	al, 0x92
	or	al, 2
	out	0x92, al
	
	call	nxtclust
	
	call	scandir
	
	jc	.fail
	
	mov	si, .ok
	call	puts
	
	mov	ax, 0x1000
.loop	push	ax
	xor	ax, ax
	mov	es, ax
	call	nxtclust
	pop	ax
	jc	.done
	mov	es, ax
	xor	di, di
	mov	si, 0xC000
	mov	cx, 512
	rep movsb
	
	add	ax, 0x20
	jmp	.loop
	
.done	call vgainit
	
	cli
	lgdt	[gdt_ptr]	; load the GDT register
	
	mov	eax, cr0 
	or	al, 1		; Enabl the PE bit in the control register
	mov	cr0, eax
	
	jmp	0x08:stage2	; 0x08 is the code selector
	
.fail	mov	si, .err
	call	puts
	jmp	halt

.msg:	DB	`stage1 bootloader loaded.\r\n`, 0
.ok:	DB	`Found kernel directory entry.\r\n`, 0
.err:	DB	`FATAL: KERNEL.BIN not found\r\n`, 0

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
	DD	0xC000
.lba	DQ	0

; the "cluster" variable tells us which cluster to load. First, we need to work
; out what the next cluster index is
nxtclust:
	mov	eax, [cluster]
	and	eax, 0x0fffffff
	cmp	eax, 0x0ffffff8
	jge	.eof
	push	eax
	shr	eax, 7
	add	eax, RESVD_SECTORS
	call	loadsect
	pop	eax
	mov	ebx, eax
	and	ebx, 0x7F
	shl	bx, 2
	mov	ebx, [ebx+0xc000]
	mov	[cluster], ebx
	add	eax, RESVD_SECTORS + FAT_SECTORS - 2
	call	loadsect
	clc
	ret
	
.eof	stc
	ret

; scan a FAT32 cluster at 0xc000 for the kernel.
; eax = kernel cluster on success
; eax = 0 on failure
scandir:
	mov	bx, 0xC000
.loop	mov	si, bx
	mov	di, .fname
	mov	cx, 11
	repe cmpsb
	je 	.success
	add	bx, 32
	cmp	bx, 0xE000
	jl	.loop
	call	nxtclust
	jnc	scandir
	ret
.success:
	mov	ax, [bx+20]
	shl	eax, 16
	mov	ax, [bx+26]
	mov	[cluster], eax
	clc
	ret

.fname:	DB	"KERNEL  BIN"

; setup VESA video mode
vgainit:
	mov	ax, 0x4F01
	mov	cx, 0x11B ; 1280x1024x24
	mov	di, vesainfo
	int	0x10
	cmp	ax, 0x004F
	jne	.fail
	mov	al, [vesainfo]
	and	al, 0x80
	je	.fail ; check that LFB is supported
	mov	ax, 0x4F02
	mov	bx, 0x411B ; 1280x1024x24, LFB enabled
	int	0x10
	cmp	ax, 0x004F
	jne	.fail
	ret
	
.fail	mov	si, .err
	call	puts
	jmp	halt

.err:	DB	`FATAL: VESA mode not supported\r\n`, 0

vesainfo:
	TIMES 256 DB 0


; Global Descriptor Table ;

gdt:
; null entry
	DD	0
	DD	0
; code descriptor
	DW	0xFFFF		; limit low
	DW	0		; base low
	DB	0		; base middle
	DB	10011010b	; access
	DB	11001111b	; granularity
	DB	0		; base high
; data descriptor
	DW	0xFFFF		; limit low
	DW	0		; base low
	DB	0		; base middle
	DB	10010010b	; access
	DB	11001111b	; granularity
	DB	0		; base high
gdt_end:

gdt_ptr:
	DW	gdt_end - gdt - 1
	DD	gdt


; stage2 bootloader code - Protected mode starts here;

	BITS	32

stage2:
	mov	ax, 0x10	; 0x10 is the data selector
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	
	mov	esp, 0x7FFFF	; where the old stack was
	
	fldcw	[.fpucw] ; init the FPU
	
	push	DWORD [vesainfo+0x19] ; bits per pixel
	push	DWORD [vesainfo+0x28] ; buffer address
	push	DWORD [vesainfo+0x32] ; bytes per line
	
	mov	edi, 0x10000
	mov	eax, 0x1337D00D
	mov	ecx, 0x100000 ; signature must be in first 1MB
	repne	scasd
	call	edi
	
	;call	0x10000		; Jump into the kernel!
	
	jmp	halt ; this should probably never happen
	
.fpucw: DW	0x37F

; padding + FAT ;

	TIMES RESVD_SECTORS*SECTOR_SIZE-($-$$) DB 0
fat:	DD	0x0FFFFFF0
	DD	0x0FFFFFFF
	DD	0x0FFFFFFF

; padding (rest of filesytem) ;

	TIMES	0x100000-($-$$) DB 0 ; Only pad to 1MB, NASM is slow at padding :(
