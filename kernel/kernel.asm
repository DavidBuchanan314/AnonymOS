	BITS	32
	ORG	0x10000 ; Where the bootloader will load us

start:
	call	cls
	
	mov	ecx, msgend - msg
	mov	esi, msg
	call	puts
	
	jmp	halt

cls: ; write a load of spaces to the screen text buffer
	mov	edi, 0xB8000
	mov	ecx, 80*25
	mov	al, ' '
.loop	stosb
	inc	edi
	loop	.loop
	ret

puts: ; very dumb print function
	mov	edi, 0xB8000
.loop	movsb
	inc	edi
	loop	.loop
	ret

halt:
	jmp	halt

msg:
	DB	"Hello from the 32-bit kernel!"
msgend:
