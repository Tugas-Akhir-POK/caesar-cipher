.include "m8515def.inc"

.org $00
	rjmp RESET

RESET:
	ldi	r16,low(RAMEND)
	out	SPL,r16	            ;init Stack Pointer		
	ldi	r16,high(RAMEND)
	out	SPH,r16

forever:
	rjmp forever
