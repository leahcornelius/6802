; -----------------------------------
; Template for programs
; -----------------------------------
; Target: MC680x with SC1 layout (see hardware/layouts)
; Assembler: SBASM v3 
; -----------------------------------

             .LI    OFF                 ; Dont print the assembly to console when assembling
             .CR    6800                ; Select cross overlay (Motorola 6802)
             .OR    $8000               ; The program will start at address $8000 
             .TF    blank.bin, BIN        ; Set raw binary output

;------------------------------------------------------------------------
;  Declaration of constants
;------------------------------------------------------------------------

PIA_A           .EQ     $0080           ; Pia data register A 
PIA_B           .EQ     $0081           ; Pia data register B 
CON_A           .EQ     $0082           ; Pia control register A
CON_B           .EQ     $0083           ; Pia control register B
RX_REGISTER     .EQ     $0100           ; Data input register 
TX_REGISTER     .EQ     $0101           ; Data output register

PORT_A_MODE     .EQ     $0064           ; Stores the mode of port A's pins (I/O)
PORT_B_MODE     .EQ     $0065           ;                  & port B
PORT_A_DATA     .EQ     $0004           ; Stores the data to be sent to & read from PIA port A
PORT_B_DATA     .EQ     $0005           ; 

DELAY_COUNTER   .EQ     $0010           ; Used for delays

; Interupts 
INTERUPT_HANDLE NOP                     ; Handle the interupt request
                RTI                     ; Return from interupt

;------------------------------------------------------------------------
;  Reset and initialisation
;------------------------------------------------------------------------

RESET           LDS     #$007F          ; Reset stack pointer
                CLRA
                CLRB
                LDAA    #%0000.0011     ; PA2-PA7 input, PA0 & PA1 output
                STAA    PORT_A_MODE
                LDAA    #%1111.1100     ; PB2-PB7 output, PB0 & PB1 input
                STAA    PORT_B_MODE
                BSR     SET_PORT_MODE
                CLR     PORT_A_DATA
                CLR     PORT_B_DATA

MAIN            NOP                     ; Put main function here
                BRA     MAIN            ; Loop until reset


; Delay utils
DELAY_100MS              LDX    #DELAY_COUNTER              ; Set delay counter and count down
.LOOP                    DEX                        ; to 0
                         BNE    .LOOP               ; Not 0 yet!
                         RTS

DELAY_LOOP               BRA    DELAY_100MS         ; Uses value in accumulator A and completes that many 100ms delays
                         DECA   
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

WRITE_PORT_DATA_A BSR ACCESS_PORT_A
                  LDAA    PORT_A_DATA
                  STAA    PIA_A
                  RTS

WRITE_PORT_DATA_B BSR ACCESS_PORT_B
                  LDAA    PORT_B_DATA
                  STAA    PIA_B
                  RTS

READ_PORT_DATA_A  BSR ACCESS_PORT_A
                  LDAA    PIA_A
                  STAA    PORT_A_PATTERN
                  RTS

READ_PORT_DATA_B  BSR ACCESS_PORT_B
                  LDAA    PIA_B
                  STAA    PORT_B_PATTERN
                  RTS


;------------------------------------------------------------------------
;  Interrupt and reset vectors
;------------------------------------------------------------------------

                .NO     $FFF8,$FF
                .DA     INTERUPT_HANDLE  ; IRQ
                .DA     INTERUPT_HANDLE  ; SWI
                .DA     RESET            ; NMI (Not used)
                .DA     RESET            ; Reset
