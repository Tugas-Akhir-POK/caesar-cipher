;====================================================================
; Processor		: ATmega8515
; Compiler		: AVRASM
;====================================================================
.include "m8515def.inc"

;====================================================================
; DEFINITIONS
;====================================================================
.def current_word = r1 ; buat nanti di get dari array untuk shift dll
.def two_minutes_counter = r2 ; simpan index untuk array
.def temp = r16 ; temporary register
.def temp2 = r17 ;temp2
.def stack = r21 ; stack
.def current_ddram = r22 ; simpan nilai ddram untuk geser2 cursor
.def banyak_input = r23
.def PB = r24 ; for PORTB
.def A  = r25 ; kalo mau nge print
.def seconds_passed = r20
.def pattern = r26
.equ twenty_seconds = 110

;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================
.org $00
	rjmp INIT_STACK
.org $06
	rjmp ov_int

;====================================================================
; CODE SEGMENT
;====================================================================
INIT_STACK:
	ldi	stack,low(RAMEND)
	out	SPL,stack	            ;init Stack Pointer
	ldi stack,high(RAMEND)
	out	SPH,stack

Main:
	;set variables
	ldi current_ddram, $C0
	ldi banyak_input, $0
	ldi temp, 6
	add two_minutes_counter, temp

	;Init I/O
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

	ldi seconds_passed, twenty_seconds
	
	rcall LOAD_ADDRESS_ARRAY
	

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

	tst two_minutes_counter
	breq end_program
	
	rjmp forever

end_program:
	rcall CLEAR_LCD
	rcall END_MESSAGE
	rcall DELAY_03
	rjmp INIT_STACK

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

INPUT_TEXT2:
	ldi ZH,high(2*message_selesai) ; Load high part of byte address into ZH
	ldi ZL,low(2*message_selesai) ; Load low part of byte address into ZL
	ret

LOADBYTE_END_MESSAGE:
	lpm ; Load byte from program memory into r0

	tst r0 ; Check if we've reached the end of the message
	breq LOADBYTE_END_MESSAGE ; If so, quit

	mov A, r0 ; Put the character onto Port B
	rcall WRITE_TEXT
	adiw ZL,1 ; Increase Z registers
	rjmp LOADBYTE
	LOADBYTE_END_MESSAGE_FINALLY:
		ret

BAWAH:
	cbi PORTA, 1
	ldi PB, $C0 ; set DDRAM address to C0 for second row
	out PORTB, PB
	sbi PORTA, 0 ; SETB EN
	cbi PORTA, 0 ; CLR EN
	rcall DELAY_01
	ret

END_MESSAGE:
	rcall INPUT_TEXT2
	rcall LOADBYTE_END_MESSAGE
	ret

END_LCD:
	rcall BAWAH ; ubah cursor ke bawah untuk input kata
	ret

INIT_TIMER:
	;ldi counter, 6
	ldi pattern, 0b00111111

	ldi r16, (1<<CS10)
	out TCCR1B,r16			
	ldi r16,1<<TOV1
	out TIFR,r16		; Interrupt if overflow occurs in T/C0
	ldi r16,1<<TOIE1
	out TIMSK,r16		; Enable Timer/Counter0 Overflow int

	ldi r16, 0b00111111
	out DDRC,r16		; Set port C as output
	ldi r16, 0
	out PORTC, r16
	mov r16, pattern
	out PORTC, r16
	sei
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
	ldi PB,$0D ; MOV DATA,0x0F --> disp ON, cursor OFF, blink ON
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
	ldi current_ddram, $C0
	mov PB, current_ddram
	cbi PORTA, 1
	out PORTB, PB 	;set address dram to second row first index
	sbi PORTA, 0
	cbi PORTA, 0

	rcall LOAD_ADDRESS_ARRAY	;load Y address
	ldi temp2, $0	;counter

	loop_kiri:
		cp temp2, banyak_input	;check if counter = banyakinput
		breq loop_kiri_beres	;if yes, then break loop
		ld temp, Y				;load char from memory
		subi temp, 1			;decrement char ascii
		mov A, temp

		cpi A, $40	;check if char is @
		brne LANJUT_LOOP_KIRI
		ldi A, $5A ; if @, then set to Z

		LANJUT_LOOP_KIRI:
		rcall WRITE_TEXT_NO_DELAY
		st Y+, A	;store back char to memory
		subi temp2, -1	;increment counter
		subi current_ddram, -1	;increment ddram address
		rjmp loop_kiri
	
	loop_kiri_beres:
	rjmp forever

SHIFT_KANAN:
	ldi current_ddram, $C0
	mov PB, current_ddram
	cbi PORTA, 1
	out PORTB, PB
	sbi PORTA, 0 ; SETB EN
	cbi PORTA, 0 ; CLR EN

	rcall LOAD_ADDRESS_ARRAY
	ldi temp2, $0

	loop_kanan:
		cp temp2, banyak_input	;cek udh berapa char yang ke shift
		breq loop_kanan_beres
		ld temp, Y		;load the char
		subi temp, -1	;add ascii
		mov A, temp		;prepare to write to LCD

		cpi A, $5B		;check if its Z
		brne LANJUT_LOOP_KANAN
		ldi A, $41		;if Z, then print A

		LANJUT_LOOP_KANAN:
		rcall WRITE_TEXT_NO_DELAY
		st Y+, A		;update char at memory
		subi temp2, -1
		
		subi current_ddram, -1	
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
	;subi banyak_input, -1

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

WRITE_TEXT_NO_DELAY:
	sbi PORTA,1 ; SETB RS
	out PORTB, A
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
	;rcall DELAY_01
	ret

WRITE_TEXT:
	sbi PORTA,1 ; SETB RS
	out PORTB, A
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
	rcall DELAY_01
	ret

ov_int:
	;test masih 0 apa ga, brarti belum di setting
	tst seconds_passed
	brne lanjut_interrupt
	reti

lanjut_interrupt:
	;siapa tau nilai penting
	push temp
	push temp2

	subi seconds_passed, 1
	tst seconds_passed ;test kalo 0 apa ga
	brne end_interrupt

	; kalo udah nol maka ganti led dan update ulang nilai seconds passed
	ldi temp, 1
	sub two_minutes_counter, temp
	ldi seconds_passed, twenty_seconds
	lsr pattern
	out PORTC, pattern

end_interrupt:
	pop temp2
	pop temp

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

DELAY_03:
; Generated by delay loop calculator
; at http://www.bretmulvey.com/avrdelay.html
;
; Delay 2 000 000 cycles
; 500ms at 4.0 MHz

    ldi  r18, 11
    ldi  r19, 38
    ldi  r20, 94
L3: dec  r20
    brne L3
    dec  r19
    brne L3
    dec  r18
    brne L3
    rjmp PC+1

ret

;====================================================================
; DATA
;====================================================================
message:
.db "Input kata :", 0
message_selesai:
.db "maaf gan, waktu sudah habis...",0
array:

