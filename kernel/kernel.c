#include <stdarg.h>

#define COM1 0x3F8

void _fake_start() { // The entry point needs to be at the start of the file
	asm("jmp _start");
}

unsigned int rsvdsect;

static inline void outb(short port, unsigned char val) {
	asm volatile ( "outb %0, %1" : : "a"(val), "Nd"(port) );
}

static inline char inb(short port) {
	char ret;
	asm volatile ( "inb %1, %0" : "=a"(ret) : "Nd"(port) );
	return ret;
}

static inline short inw(short port) {
	short ret;
	asm volatile ( "inw %1, %0" : "=a"(ret) : "Nd"(port) );
	return ret;
}

void putc_serial(char c) {
	while (!(inb(COM1 + 5) & 0x20));
	outb(COM1, c);
}

void puts_serial(const char * str) {
	const char *s = str;
	while (*s) {
		putc_serial(*s++);
	}
	putc_serial('\n');
}

int memcmp(const void *s1, const void *s2, int n) {
	const unsigned char *l = s1, *r = s2;
	while (*l++ == *r++ && n--);
	return *l - *r;
}

void memcpy(void *dest, const void *src, int n) {
	unsigned char *d = dest;
	const unsigned char *s = src;
	for (int i = 0; i < n; i++) {
		d[i] = s[i];
	}
}

void printf_serial(char * fmt, ...) { // TODO: make robust
	unsigned int arg;
	char hexmap[] = "0123456789ABCDEF";
	
	va_list args;
	va_start(args, fmt);
	while (*fmt) {
		switch (*fmt) {
			case '%':
				switch(*(++fmt)) {
					case 'x':
					case 'X':
						arg = va_arg(args,int);
						char buf[8];// = "000000000"; // This is really janky, for some reason having 8 0's causes the first to stay unchanged
						for (int i = 7; i >= 0; i--) {
							buf[i] = hexmap[arg & 0xF];
							arg >>= 4;
						}
						for (int i = 0; i < 8; i++) putc_serial(buf[i]);
						break;
					case '%':
						putc_serial('%');
						break;
					default:
						putc_serial('%');
						putc_serial(*fmt);
				}
				fmt++;
				break;
			default:
				putc_serial(*fmt++);
		}
	}
	va_end(args);
}

void read_sector(void * buf, int lba) {
	
	outb(0x1F6, 0x40);
	outb(0x1F2, 0); // sector count high
	outb(0x1F3, lba >> 24); // LBA 4
	outb(0x1F4, 0); // LBA 5
	outb(0x1F5, 0); // LBA 6
	outb(0x1F2, 1); // sector count low
	outb(0x1F3, lba); // LBA 1
	outb(0x1F4, lba >> 8); // LBA 2
	outb(0x1F5, lba >> 16); // LBA 3
	outb(0x1F7, 0x24); // READ SECTORS EXT
	
	while (inb(0x1F7) & 0x80); // poll until ready
	
	for (int i = 0; i < 256; i++) {
		((short *) buf)[i] = inw(0x1F0);
	}
}

int next_cluster(void * buf, int clust) {
	read_sector(buf, rsvdsect + clust/128);
	return ((unsigned int *) buf)[clust % 128] & 0x0FFFFFFF;
}

int load_file(void * dst, char * name) {
	char buf[512];
	
	read_sector(buf, 0);
	
	unsigned int rootclust = * (unsigned int *) &buf[0x2C];
	unsigned int fatsize = * (unsigned int *) &buf[0x24];
	rsvdsect = * (unsigned short *) &buf[0xE];
	unsigned int fileclust = 0;
	unsigned int filelen = 0;
	unsigned int writei = 0;
	
	printf_serial("Reserved sectors: 0x%X\n", rsvdsect);
	printf_serial("Number of FAT sectors: 0x%X\n", fatsize);
	
	while (rootclust < 0x0ffffff8) {
		printf_serial("FAT cluster: 0x%X\n", rootclust);
		read_sector(buf, rsvdsect + fatsize + rootclust - 2);
		
		for (int i = 0; i < 512; i += 32) {
			//puts_serial(&buf[i]);
			if (memcmp(name, &buf[i], 11) == 0) {
				fileclust = * (unsigned short *) &buf[i + 20];
				fileclust <<= 16;
				fileclust |= * (unsigned short *) &buf[i + 26];
				filelen = * (unsigned int *) &buf[i + 0x1C];
				break;
				
			}
		}
		
		if (fileclust != 0) break;
		
		rootclust = next_cluster(buf, rootclust);
	}
	
	if (fileclust == 0) {
		puts_serial("File not found.");
		return 0;
	}
	
	printf_serial("File length: 0x%X\n", filelen);
	
	while (fileclust < 0x0ffffff8) {
		printf_serial("File cluster: 0x%X\n", fileclust);
		read_sector(&((char *)dst)[writei], rsvdsect + fatsize + fileclust - 2);
		writei += 512;
		fileclust = next_cluster(buf, fileclust);
	}
	
	if (writei < filelen) {
		puts_serial("Didn't read the whole file...");
		return writei;
	}
	
	printf_serial("Done reading file!\n");
	
	return filelen;
}

void _start(short bpl, unsigned char * vbuf, unsigned char bpp) {
	bpp /= 8;
	
	char buf[512];
	
	//read_sector(buf, 0);
	//puts_serial(&buf[3]);
	printf_serial("Framebuffer at 0x%X\n", vbuf);
	
	//load_file(buf, "HELLO   TXT");
	//printf_serial(buf);
	
	char * splash = (void *) 0x400000;
	load_file(splash, "SPLASH  PPM");
	
	// Render the mandelbrot set
	/*for (int y = 0; y < 1024; y++) {
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
	}*/
	
	for (int y = 0; y < 1024; y++) {
		for (int x = 0; x < 1280; x++) {
			vbuf[y*bpl+x*bpp] = splash[17+y*1280*3+x*3+2];
			vbuf[y*bpl+x*bpp+1] = splash[17+y*1280*3+x*3+1];
			vbuf[y*bpl+x*bpp+2] = splash[17+y*1280*3+x*3];
		}
	}
	
	return;
}
