;====================================================================
; Processor		: ATmega8515
; Compiler		: AVRASM
;====================================================================
.include "m8515def.inc"

;====================================================================
; DEFINITIONS
;====================================================================
.def current_word = r1 ; buat nanti di get dari array untuk shift dll
.def current_index = r2 ; simpan index untuk array
.def temp = r16 ; temporary register
.def shift = r17 ; shift berapa
.def stack = r21 ; stack
.def current_ddram = r22 ; simpan nilai ddram untuk geser2 cursor
.def EW = r23 ; for PORTA
.def PB = r24 ; for PORTB
.def A  = r25 ; kalo mau nge print

;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================
.org $00
	rjmp INIT_STACK

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
	rcall INIT_INTERRUPT
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


forever:
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
	ret

INIT_INTERRUPT:
	;ldi temp,0b00000010
	;out MCUCR,temp
	;ldi temp,0b01000000
	;out GICR,temp
	;sei
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
	in XL, SPL
	in XH, SPH
	st X, A
	ret

END_LCD:
	rcall BAWAH ; ubah cursor ke bawah untuk input kata
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

SHIFT_KIRI:
	ldi A, $42
	rcall WRITE_TEXT

	rcall DELAY_01
	rjmp forever

SHIFT_KANAN:
	ldi A, $43
	rcall WRITE_TEXT

	rcall DELAY_01
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
	rcall SIMPAN_STACK
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

	rcall DELAY_01
	rjmp forever

WRITE_TEXT:
	sbi PORTA,1 ; SETB RS
	out PORTB, A
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
	rcall DELAY_01
	ret

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
.db "Input kata :",0
