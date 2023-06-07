            .CR    6800                ; Select cross overlay (Motorola 6802)
            .OR    $E000               ; The program will start at address $8000 
            .TF    bootloader.hex, BIN ; Set raw binary output

_append_char:
	;invalid XDP
	ldaa _buffer_head
	ldab _buffer_head+1
	pshb
	psha
	tsx
	clra
	ldab $04,x 
	tsx
	ldx $00,x
	ins
	ins
	stab $00,x
	;invalid XDP
	ldaa _buffer_head
	ldab _buffer_head+1
	staa tmp1
	stab tmp1+1
	addb #$01
	adca #$00
	staa _buffer_head
	stab _buffer_head+1
	ldaa tmp1
	ldab tmp1+1
	ldaa _buffer_head
	ldab _buffer_head+1
	cmpa #$01
	bne L000B
	cmpb #$00
L000B:
	jsr BOOLEQ
	beq L0009
	;invalid XDP
	clra
	clrb
	staa _buffer_head
	stab _buffer_head+1
L0009:
L0005:
	jmp ret1

BOOLEQ          

_buffer_head    .EQ $0005
_buffer_tail    .EQ $0007
_buffer         .EQ $00010
tmp1            .EQ $0001
