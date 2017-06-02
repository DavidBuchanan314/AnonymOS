void _start(short bpl, unsigned char * vbuf, unsigned char bpp) {
	bpp /= 8;
	
	for (int y = 0; y < 1024; y++) {
		for (int x = 0; x < 1280; x++) {
			vbuf[y*bpl+x*bpp] = x;
			vbuf[y*bpl+x*bpp+1] = y;
			vbuf[y*bpl+x*bpp+2] = x+y;
		}
	}
	
	return;
}
