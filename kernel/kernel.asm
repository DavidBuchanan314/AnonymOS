	BITS 16
	ORG 0x10000 ; will eventually be 32-bit

start:
	mov	si, msg
	call	puts
	mov	si, test
	call	puts
	cli
	hlt

puts: ; string in si
	mov	ah, 0x0e
.loop	lodsb
	or	al, al
	jz	.done
	int	0x10
	jmp	.loop
.done	ret

msg:	DB `AnonymOS kernel loaded!!!\r\n`, 0
test:	DB "Testing really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really long strings (to make the kernel take up mutiple clusters on disk)", 0
