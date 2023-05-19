; -----------------------------------
; Will attempt to read the data recieved (into SIPO 0) and then echo it back (through tx PISO)
; -----------------------------------
; Target: MC680x with SC1 layout (see hardware/layouts)
; Assembler: SBASM v3 
; -----------------------------------

             .LI    OFF                 ; Dont print the assembly to console when assembling
             .CR    6800                ; Select cross overlay (Motorola 6802)
             .OR    $8000               ; The program will start at address $8000 
             .TF    uart.bin, BIN        ; Set raw binary output

;------------------------------------------------------------------------
;  Declaration of constants
;------------------------------------------------------------------------

PIA_A           .EQ     $80           ; Pia data register A 
PIA_B           .EQ     $81           ; Pia data register B 
CON_A           .EQ     $82           ; Pia control register A
CON_B           .EQ     $83           ; Pia control register B
UART_RTX_REG    .EQ     $90           ; UART RX/TX data registers
UART_CTRL_REG   .EQ     $88           ; UART controll & status registers

RX_BUFFER_START .EQ     $0D           ; This and the address aboe it used to store read RX data (0xD & 0xE)

PORT_A_MODE     .EQ     $04           ; Stores the mode of port A's pins (I/O)
PORT_B_MODE     .EQ     $05           ;                  & port B
PORT_A_DATA     .EQ     $06           ; Buffers the data to be sent to & that is read from PIA port A
PORT_B_DATA     .EQ     $07           ;                                                        &    B

DELAY_COUNTER   .EQ     $0A           ; Stores delay counter
DELAY_ITERS     .EQ     $09           ; Number of 100ms delays for DELAY_LOOP

; Interupts 
INTERUPT_HANDLE NOP                     ; Handle the interupt request
                                        ; Blinks the leds to show interupts are being recieved (as a test)
                LDAA    #25
                STAA    DELAY_ITERS
                LDAA    #%0000.0100
                STAA    CON_B
                LDAA    #%1010.1010
                LDAB    #%0101.0101
                STAA    PIA_B
                BSR     DELAY_LOOP
                STAB    PIA_B
                BSR     DELAY_LOOP
                STAA    PIA_B
                BSR     DELAY_LOOP
                STAB    PIA_B
                BSR     DELAY_LOOP
                CLR     PIA_B
                CLR     CON_B
                RTI                     ; Return from interupt

;------------------------------------------------------------------------
;  Reset and initialisation
;------------------------------------------------------------------------

RESET           LDS     #$7F          ; Reset stack pointer
                LDX     #0              ; & the index pointer
                CLRA
                CLRB
                LDAA    #%0000.0011     ; PA2-PA7 input, PA0 & PA1 output
                STAA    PORT_A_MODE
                LDAA    #%1111.1111     ; PB0-PB7 output (all)
                STAA    PORT_B_MODE
                BSR     SET_PORT_MODE
                CLR     PORT_A_DATA
                CLR     PORT_B_DATA    
                LDX     RX_BUFFER_START
                CLR     0,X
                CLR     1,X
                CLI                     ; Enable interupts

MAIN            BSR     WRITE_PORT_DATA_B
                BSR     DELAY_100MS     ; Short delay between increments (always)
                INC     PORT_B_DATA    
                BVC     MAIN            ; Only continue if overflow set
                LDAA    #10             ; Long delay of 1s (after overflow)
                STAA    DELAY_ITERS
                BSR     DELAY_LOOP      ; Long delay on pattern overflow
                BRA     MAIN            ; Loop until reset


; Delay utils
DELAY_100MS              LDX    DELAY_COUNTER              ; Set delay counter and count down
.LOOP                    DEX                        ; to 0
                         BNE    .LOOP               ; Not 0 yet!
                         RTS

DELAY_LOOP               BSR    DELAY_100MS         ; Uses value in ram and completes that many 100ms delays
                         DEC    DELAY_ITERS   
                         BNE    DELAY_LOOP
                         RTS
                        
; PIA port utils

SET_PORT_MODE   LDAB    #%0000.0100
                STAB    CON_A
                STAB    CON_B
                LDAA    PORT_A_MODE
                LDAB    PORT_B_MODE
                STAA    PIA_A
                STAB    PIA_B
                CLRA    
                STAA    CON_A
                STAA    CON_B
                RTS

ACCESS_PORT_A     LDAA    #%0000.0100
                  STAA    CON_A
                  RTS

ACCESS_PORT_B     LDAA    #%0000.0100
                  STAA    CON_B
                  RTS

WRITE_PORT_DATA_A BSR     ACCESS_PORT_A
                  LDAA    PORT_A_DATA
                  STAA    PIA_A
                  RTS

WRITE_PORT_DATA_B BSR     ACCESS_PORT_B
                  LDAA    PORT_B_DATA
                  STAA    PIA_B
                  RTS

READ_PORT_DATA_A  BSR     ACCESS_PORT_A
                  LDAA    PIA_A
                  STAA    PORT_A_DATA
                  RTS

READ_PORT_DATA_B  BSR     ACCESS_PORT_B
                  LDAA    PIA_B
                  STAA    PORT_B_DATA
                  RTS


;------------------------------------------------------------------------
;  Interrupt and reset vectors
;------------------------------------------------------------------------

                .NO     $FFF8,$FF
                .DA     INTERUPT_HANDLE  ; IRQ
                .DA     RESET            ; SWI (Not used)
                .DA     RESET            ; NMI (Not used)
                .DA     RESET            ; Reset
