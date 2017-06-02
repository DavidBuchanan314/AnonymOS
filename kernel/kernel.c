#define COM1 0x3F8

void _fake_start() { // The entry point needs to be at the start of the file
	asm("jmp start");
}

static inline void outb(short port, char val) {
	asm volatile ( "outb %0, %1" : : "a"(val), "Nd"(port) );
}

static inline char inb(short port) {
	char ret;
	asm volatile ( "inb %1, %0" : "=a"(ret) : "Nd"(port) );
	return ret;
}

void putc_serial(char c) {
	while (!(inb(COM1 + 5) & 0x20));
	outb(COM1, c);
}

void puts_serial(char * str) {
	while (*str) {
		putc_serial(*str++);
	}
	putc_serial('\r');
	putc_serial('\n');
}

void start(short bpl, unsigned char * vbuf, unsigned char bpp) {
	bpp /= 8;
	
	char * hello = "Hello, serial port!";
	puts_serial(hello);
	
	for (int y = 0; y < 1024; y++) {
		for (int x = 0; x < 1280; x++) {
			float x0 = ((float)x - 800) / 400;
			float y0 = ((float)y - 512) / 400;
			float xn = 0.0;
			float yn = 0.0;
			int i;
			
			for (i = 0; i < 32 && xn*xn + yn*yn < 4; i++) {
				float xtemp = xn*xn - yn*yn + x0;
				yn = 2*xn*yn + y0;
				xn = xtemp;
			}
			
			if (i == 32) i = 0;
			i *= 8;
			
			vbuf[y*bpl+x*bpp] = i;
			vbuf[y*bpl+x*bpp+1] = i;
			vbuf[y*bpl+x*bpp+2] = i;
		}
	}
	
	return;
}
