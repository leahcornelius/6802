; -----------------------------------
; load.asm - Leah Cornelius 14/05/23
; Loads data a bit at a time on PA1,
; rising-edge clocked by PA2 and
; start-stop(ed) by PA3. See 
; 'Software/CL23.ino' for the 
; corrosponding arduino sketch
; -----------------------------------
; Target: MC680x with SC1 layout (see hardware/layouts)
; Assembler: SBASM v3 
; -----------------------------------

            ; .LI    OFF                 ; Dont print the assembly to console when assembling
             .CR    6800                ; Select cross overlay (Motorola 6802)
             .OR    $8000               ; The program will start at address $8000 
             .TF    corn8.hex, BIN        ; Set raw binary output

;------------------------------------------------------------------------
;  Declaration of constants
;------------------------------------------------------------------------

PIA_A           .EQ     $0080           ; Pia data register A 
PIA_B           .EQ     $0081           ; Pia data register B 
CON_A           .EQ     $0082           ; Pia control register A
CON_B           .EQ     $0083           ; Pia control register B
PORT_B_PATTERN  .EQ     $0005           ; Pattern for port B
STACK_POINTER   .EQ     $007F           ; Use internal RAM for stack
PAGE_ONE        .EQ     $0800           ; The start address 0 of page 1
PAGE_TWO        .EQ     $1000           ;                  and page two

BIT_INDEX       .EQ     $0000           ; The memory location where the bit index is stored
BIT_SHIFT_ROUND .EQ     $0001           ; The memory location where the bit shift round is stored
SERIAL_RX_BYTE  .EQ     $0002           ; The memory location where the byte recieved is buffered
USER_CODE_START .EQ     $000F           ; The offset within page 1 where code is is stored (upwards)
DELAY_COUNTER   .EQ     12500           ;    Delay counter for approx. 100ms.

;------------------------------------------------------------------------
;  Reset and initialisation
;------------------------------------------------------------------------

RESET           LDS     #STACK_POINTER       ; Reset stack pointer
                LDX     #PAGE_ONE       ; Set index register to start of page 1
                LDAA    #%0000.0100     ; Initialise PIA ports
                STAA    CON_A
                STAA    CON_B
                LDAA   #%0001.1111       ;  b0..b4 are outputs b5+b6+b7 are
                STAA   PIA_A             ;  inputs for both PIA ports
                STAA   PIA_B
                CLRB
                STAB    CON_A
                STAB    CON_B
                STAA    PIA_A
                STAA    PIA_B
                LDAA    #%0000.0100     ; Select data registers again
                STAA    CON_A
                STAA    CON_B
                LDAA    #%1111.1111     
                STAA    PORT_B_PATTERN ; Led pattern for port B
                CLRA
                CLRB


;------------------------------------------------------------------------
;  Main program loop
;------------------------------------------------------------------------

MAIN                     LDAA   PIA_A
                         ANDA   #%1000.0000
                         BEQ    .USER_BUTTON_DOWN
                         LDAA   #2
                         BSR    .DELAY_LOOP

                
     

.USER_BUTTON_DOWN        CLRA
                         STAA PIA_B
                         LDAA #10 ; 1000ms delay
                         BSR DELAY_LOOP
                         LDAA #$FF
                         STAA PIA_B
                         BSR DELAY_100MS
                         CLRA
                         STAA PIA_B
                         ;BSR  START_RX
                         RTS
                
;------------------------------------------------------------------------
; Delay subroutine for approx 100ms
;------------------------------------------------------------------------

DELAY_100MS              LDX    #DELAY_COUNTER              ; Set delay counter and count down
.LOOP                    DEX                        ; to 0
                         BNE    .LOOP               ; Not 0 yet!
                         RTS

DELAY_LOOP               BRA    DELAY_100MS  
                         DECA   
                         BNE    DELAY_LOOP
                         RTS


;------------------------------------------------------------------------
;  Blink LEDs on PIA port B (PB0 -> PB6)
;------------------------------------------------------------------------

UPDATE_PATTERN           LDAA    PORT_B_PATTERN    ; Get current LED pattern
                         INCA
                         STAA    PORT_B_PATTERN
                         RTS

REFRESH_LEDS             LDAA    PORT_B_PATTERN
                         STAA    PIA_B           ; Send to PIA
                         RTS


WRITE_USERBYTE           STAB   USER_CODE_START,X 
                         INX
                         RTS


; Bit bang "serial" port
START_RX                 LDAA   #%0000.0001 ; PB0 is pulled high to signify the start of comms
                         STAA   PIA_B
                         BSR    DELAY_100MS
                         LDAA   #%0000.0000 ; PB0 is pulled low again
                         STAA   PIA_B
                         BSR    .WAIT_RX
                         CLRB
                         BSR   .READ_BYTE
                         LDAB  SERIAL_RX_BYTE
                         BSR  WRITE_USERBYTE
                         CLRB 
                         LDAA   PIA_B ; Read in the byte, check if PB5 is high (stop bit)
                         ANDA   #%0010.0000 ; Mask out all but PB5
                         BEQ    .END_RX 
                         BRA    START_RX ; Start again
.END_RX                  RTS
.WAIT_RX                 LDAA   PIA_B ; PB7 is start bit
                         ANDA   #%1000.0000 ; Mask out all but PB7
                         BEQ    .WAIT_RX ; Wait for start bit
.READ_BYTE               LDAA   PIA_B ; Read in the byte, check if PB7 is high (clock signal)
                         ANDA   #%1000.0000 ; Mask out all but PB7
                         BEQ    .READ_BYTE ; Wait for clock signal
                         ; Clock pulse recieved, a new bit is ready to be read on PB6
                         LDAA   PIA_B ; Read in the byte, check if PB6 is high (data signal)
                         ANDA   #%0100.0000 ; Mask out all but PB6 
                         ; Update the byte in memory with the new bit
                         BEQ    .BIT_LOW
                         LDAA   #%0000.0001
                         ORAA   SERIAL_RX_BYTE
                         STAA   SERIAL_RX_BYTE
                         BRA    .BIT_DONE
               
.BIT_LOW                 LDAA   #%1111.1110
                         ANDA   SERIAL_RX_BYTE
                         STAA   SERIAL_RX_BYTE

.BIT_DONE                INC    BIT_INDEX    ; Increment the bit index
                         LDAA   #$08         ; Check if we have read in 8 bits
                         CMPA  BIT_INDEX
                         BNE   .WAIT_RX     ; If not, wait for the next bit
                         ; 8 bits have been read in, reset the bit index
                         CLRA
                         STAA  BIT_INDEX
                         RTS



;------------------------------------------------------------------------
;  Interrupt and reset vectors
;------------------------------------------------------------------------

                .NO     $FFF8,$FF
                .DA     RESET           ;IRQ (Not used)
                .DA     RESET           ;SWI (Not used)
                .DA     RESET           ;NMI (Not used)
                .DA     RESET           ;Reset
