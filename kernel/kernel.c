void _start(short bpl, unsigned char * vbuf, unsigned char bpp) {
	bpp /= 8;
	
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
