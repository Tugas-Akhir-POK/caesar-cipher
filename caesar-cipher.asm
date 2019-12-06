;====================================================================
; Processor		: ATmega8515
; Compiler		: AVRASM
;====================================================================
.include "m8515def.inc"

;====================================================================
; DEFINITIONS
;====================================================================
.def current_word = r1 ; buat nanti di get dari array untuk shift dll
.def adressarray = r2 ; simpan index untuk array
.def temp = r16 ; temporary register
.def temp2 = r17 ;temp2
.def stack = r21 ; stack
.def current_ddram = r22 ; simpan nilai ddram untuk geser2 cursor
.def banyak_input = r23
.def PB = r24 ; for PORTB
.def A  = r25 ; kalo mau nge print
.def counter = r20
.def pattern = r26

;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================
.org $00
	rjmp INIT_STACK
.org $07
	rjmp ISR_TOV0

;====================================================================
; CODE SEGMENT
;====================================================================
INIT_STACK:
	ldi	stack,low(RAMEND)
	out	SPL,stack	            ;init Stack Pointer
	ldi stack,high(RAMEND)
	out	SPH,stack

Main:
	ldi current_ddram, $C0
	ldi banyak_input, $0
	rcall INIT
	rcall INPUT_TEXT
	ldi A, $41 ; inisiasi input nya pertama adalah huruf A
	mov current_word, A
	rcall WRITE_TEXT
	rcall DELAY_02 ; delay 2, ga terlalu lama

	;; ini buat pointer nya tetep di huruf A
	cbi PORTA, 1
	mov PB, current_ddram; set DDRAM address to 192 for second row
	out PORTB, PB
	sbi PORTA, 0 ; SETB EN
	cbi PORTA, 0 ; CLR EN
	
	rcall LOAD_ADDRESS_ARRAY
	

forever:
	;ldi A, $41
	;rcall WRITE_TEXT
	; PIND is listening to PORTD (Button)
	sbic PIND, 2 ; skip next ins if bit 2 is 0
	rjmp GANTI_HURUF ; bit 2 should be 1

	sbic PIND, 3 ; skip next ins if bit 3 is 0
	rjmp LANJUT ; bit 3 should be 1

	sbic PIND, 4 ; skip next ins if bit 4 is 0
	rjmp SHIFT_KANAN ; bit 4 should be 1

	sbic PIND, 5 ; skip next ins if bit 5 is 0
	rjmp SHIFT_KIRI ; bit 5 should be 1
	
	rjmp forever

INIT:
	rcall INIT_LED
	rcall INIT_LCD_MAIN
	rcall INIT_TIMER
	ret

INIT_LED:
	ser temp ; load $FF to temp
	out DDRC,temp ; Set PORTC to output
	ret

INPUT_TEXT:
	ldi ZH,high(2*message) ; Load high part of byte address into ZH
	ldi ZL,low(2*message) ; Load low part of byte address into ZL
	ret

INIT_LCD_MAIN:
	rcall INIT_LCD

	ser temp
	out DDRA,temp ; Set port A (LCD) as output
	out DDRB,temp ; Set port B (LCD) as output

	rcall INPUT_TEXT

LOADBYTE:
	lpm ; Load byte from program memory into r0

	tst r0 ; Check if we've reached the end of the message
	breq END_LCD ; If so, quit

	mov A, r0 ; Put the character onto Port B
	rcall WRITE_TEXT
	adiw ZL,1 ; Increase Z registers
	rjmp LOADBYTE

BAWAH:
	cbi PORTA, 1
	ldi PB, $C0 ; set DDRAM address to C0 for second row
	out PORTB, PB
	sbi PORTA, 0 ; SETB EN
	cbi PORTA, 0 ; CLR EN
	rcall DELAY_01
	ret

SIMPAN_STACK:
	;; simpan ke stack
	;in XL, SPL
	;in XH, SPH
	;st X, A
	;ret

END_LCD:
	rcall BAWAH ; ubah cursor ke bawah untuk input kata
	ret

INIT_TIMER:
	ldi counter, 8
	ldi pattern, 0b11111111
	ldi r16, (1<<CS10)||(1<<CS12) 
	out TCCR1B,r16			
	ldi r16,1<<TOV1
	out TIFR,r16		; Interrupt if overflow occurs in T/C0
	ldi r16,1<<TOIE1
	out TIMSK,r16		; Enable Timer/Counter0 Overflow int
	ldi r16, 0b11111111
	out DDRC,r16		; Set port C as output
	ldi r16, 0
	out PORTC, r16
	mov r16, pattern
	out PORTC, r16
	;sei
	ret

INIT_LCD:
	;; Function Set
	cbi PORTA,1 ; CLR RS
	ldi PB,0x38 ; MOV DATA,0x38 --> 8bit, 2line, 5x7
	out PORTB,PB
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
	rcall DELAY_01
	;;Display ON/OFF control
	cbi PORTA,1 ; CLR RS
	ldi PB,$0F ; MOV DATA,0x0F --> disp ON, cursor ON, blink ON
	out PORTB,PB
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
	rcall DELAY_01
	rcall CLEAR_LCD ; CLEAR LCD
	;;Entry Mode Set
	cbi PORTA,1 ; CLR RS
	ldi PB,$06 ; MOV DATA,0x06 --> increase cursor, display sroll OFF
	out PORTB,PB
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
	rcall DELAY_01
	ret

CLEAR_LCD:
	cbi PORTA,1 ; CLR RS
	ldi PB,$01 ; MOV DATA,0x01
	out PORTB,PB
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
	rcall DELAY_01
	ret

LOAD_ADDRESS_ARRAY:
	ldi YH,high(2*array) ; Load high part of byte address into YH
	ldi YL,low(2*array) ; Load low part of byte address into YL
	ret

SHIFT_KIRI:
	rcall LOAD_ADDRESS_ARRAY
	loop:
		ld temp, Y
		
	ldi A, $42
	rcall WRITE_TEXT

	rcall DELAY_01
	rjmp forever

SHIFT_KANAN:
	ldi current_ddram, $C0
	mov PB, current_ddram
	cbi PORTA, 1
	out PORTB, PB
	sbi PORTA, 0 ; SETB EN
	cbi PORTA, 0 ; CLR EN

	rcall LOAD_ADDRESS_ARRAY
	ldi temp2, 1
	loop_kanan:
		ld temp, Y		;load the char
		subi temp, -1	;add ascii
		mov A, temp		;prepare to write to LCD

		cpi A, $5B		;check if its Z
		brne LANJUT_LOOP_KANAN
		ldi A, $41		;if Z, then print A

		LANJUT_LOOP_KANAN:
		rcall WRITE_TEXT
		st Y+, A		;update char at memory
		subi temp2, -1
		
		subi current_ddram, -1	
		cp temp2, banyak_input	;cek udh berapa char yang ke shift
		breq loop_kanan_beres
		rjmp loop_kanan

	loop_kanan_beres:
	rjmp forever


GANTI_HURUF:
	;; ambil current word dan ditambah 1
	ldi temp, 1
	add current_word, temp
	
	mov temp, current_word
	cpi temp, $5B
	brne LOLOS
	
	ldi temp, $41
	mov current_word, temp
	
LOLOS:
	mov A, current_word
	rcall WRITE_TEXT

	mov PB, current_ddram; set DDRAM address to 192 for second row
	cbi PORTA, 1
	out PORTB, PB
	sbi PORTA, 0 ; SETB EN
	cbi PORTA, 0 ; CLR EN
	rcall DELAY_01
	rjmp forever

LANJUT:
	mov A, current_word
	st Y+, A		;Post increment store current char to memory
	subi banyak_input, -1

	;set next char
	ldi A, $41
	mov current_word, A
	ldi temp, 1
	add current_ddram, temp

	mov PB, current_ddram; set DDRAM address to 192 for second row
	cbi PORTA, 1
	out PORTB, PB
	sbi PORTA, 0 ; SETB EN
	cbi PORTA, 0 ; CLR EN

	rcall WRITE_TEXT

	mov PB, current_ddram; set DDRAM address to 192 for second row
	cbi PORTA, 1
	out PORTB, PB
	sbi PORTA, 0 ; SETB EN
	cbi PORTA, 0 ; CLR EN
	
	subi banyak_input, -1
	rcall DELAY_01
	rjmp forever

WRITE_TEXT:
	sbi PORTA,1 ; SETB RS
	out PORTB, A
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
	rcall DELAY_01
	ret

ISR_TOV0:
	dec counter
	breq MAU_UBAH_PATTERN
	rcall PILIH_KEDIP
	ldi r22, 0
	out TCNT0,r22
	reti

PILIH_KEDIP:
	cpi pattern, 0b11111111
	breq KEDIP8
	cpi pattern, 0b01111111
	breq KEDIP7
	cpi pattern, 0b00111111
	breq KEDIP6
	cpi pattern, 0b00011111
	breq KEDIP5
	cpi pattern, 0b00001111
	breq KEDIP4
	cpi pattern, 0b00000111
	breq KEDIP3
	cpi pattern, 0b00000011
	breq KEDIP2
	cpi pattern, 0b00000001
	breq KEDIP1
	ret

KEDIP8:
	ldi r16, 0b01111111
	out PORTC, r16
	rcall DELAY_00
	out PORTC, pattern
	rcall DELAY_00
	ret

KEDIP7:
	ldi r16, 0b00111111
	out PORTC, r16
	rcall DELAY_00
	out PORTC, pattern
	rcall DELAY_00
	ret

KEDIP6:
	ldi r16, 0b00011111
	out PORTC, r16
	rcall DELAY_00
	out PORTC, pattern
	rcall DELAY_00
	ret

KEDIP5:
	ldi r16, 0b00001111
	out PORTC, r16
	rcall DELAY_00
	out PORTC, pattern
	rcall DELAY_00
	ret

KEDIP4:
	ldi r16, 0b00000111
	out PORTC, r16
	rcall DELAY_00
	out PORTC, pattern
	rcall DELAY_00
	ret

MAU_UBAH_PATTERN:
	rjmp UBAH_PATTERN

KEDIP3:
	ldi r16, 0b00000011
	out PORTC, r16
	rcall DELAY_00
	out PORTC, pattern
	rcall DELAY_00
	ret

KEDIP2:
	ldi r16, 0b00000001
	out PORTC, r16
	rcall DELAY_00
	out PORTC, pattern
	rcall DELAY_00
	ret

KEDIP1:
	ldi r16, 0b00000000
	out PORTC, r16
	rcall DELAY_00
	out PORTC, pattern
	rcall DELAY_00
	ret

UBAH_PATTERN:
	ldi counter, 8
	push r16
	in r16,SREG
	push r16
	lsr pattern		; ubah pattern
	mov r16, pattern
	out PORTC, r16
	rcall DELAY_00
	pop r16
	out SREG,r16
	pop r16
	out TCNT0,r22
	reti

DELAY_01:
	; Generated by delay loop calculator
	; at http://www.bretmulvey.com/avrdelay.html
	;
	; DELAY_CONTROL 40 000 cycles
	; 5ms at 8.0 MHz

	    ldi  r18, 52
	    ldi  r19, 242
	L1: dec  r19
	    brne L1
	    dec  r18
	    brne L1
	    nop
	ret

DELAY_00:
	; Generated by delay loop calculator
	; at http://www.bretmulvey.com/avrdelay.html
	;
	; Delay 4 000 cycles
	; 500us at 8.0 MHz
	    ldi  r18, 208
	    ldi  r19, 202
	L0: dec  r19
	    brne L0
	    dec  r18
	    brne L0
	ret

DELAY_02:
	; Generated by delay loop calculator
; at http://www.bretmulvey.com/avrdelay.html
;
; Delay 4 cycles
; 1us at 4.0 MHz

    rjmp PC+1
    rjmp PC+1

	ret

;====================================================================
; DATA
;====================================================================
message:
.db "Input kata :", 0

array:
.db 0
