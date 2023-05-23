; -----------------------------------
; Will attempt to read the data recieved (into SIPO 0) and then echo it back (through tx PISO)
; -----------------------------------
; Target: MC680x with SC1 layout (see hardware/layouts)
; Assembler: SBASM v3 
; -----------------------------------

             .LI    OFF                 ; Dont print the assembly to console when assembling
             .CR    6800                ; Select cross overlay (Motorola 6802)
             .OR    $8000               ; The program will start at address $8000 
             .TF    echo.hex, BIN        ; Set raw binary output

;------------------------------------------------------------------------
;  Declaration of constants
;------------------------------------------------------------------------

PIA_A           .EQ     $80           ; Pia data register A 
PIA_B           .EQ     $81           ; Pia data register B 
CON_A           .EQ     $82           ; Pia control register A
CON_B           .EQ     $83           ; Pia control register B
RX_REGISTER0    .EQ     $88           ; Data input register 0 (LSB)
RX_REGISTER1    .EQ     $90           ;                     1 (MSB)
TX_REGISTER     .EQ     $98           ; Data output register
TX_STATUS_LINE  .EQ     $A0           ; Tx status line

RX_BUFFER_START .EQ     $0A           ; This and the address aboe it used to store read RX data (0xA & 0xB)

PORT_A_MODE     .EQ     $64           ; Stores the mode of port A's pins (I/O)
PORT_B_MODE     .EQ     $65           ;                  & port B
PORT_A_DATA     .EQ     $04           ; Stores the data to be sent to & read from PIA port A
PORT_B_DATA     .EQ     $05           ; 

DELAY_COUNTER   .EQ     $10           ; Used for delays

UART_STATUS     .EQ     $11           ; State machine for UART
PACKET_COUNT    .EQ     $12

; Interupts 
INTERUPT_HANDLE NOP                     ; Handle the interupt request
                BSR     UART_INTERUPT
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
                CLR     UART_STATUS
                CLR     PACKET_COUNT
                LDX     RX_BUFFER_START
                CLR     0,X
                CLR     1,X
                CLI                     ; Enable interupts

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

; UART buffer utils    
READ_RX_BUFFER          LDX     RX_BUFFER_START
                        LDAA    RX_REGISTER0
                        LDAB    RX_REGISTER1
                        STAA    0,X
                        STAB    1,X
                        RTS

TX_BYTE                 STAA    TX_REGISTER
                        BRA     ACK_PULSE_BYTE
                        RTS

ACK_PULSE_BYTE          STAA    TX_STATUS_LINE  ; Doesnt store anything, just brings status line low 
                        RTS

UART_INTERUPT           LDAA    UART_STATUS
                        CMPA    #0              ; Uninitalised
                        BNE     .ELSE_A
                        BEQ     .UART_HANDSHAKE_BEGIN
                        BRA     .END_IF
            .ELSE_A     CMPA    #1              ; Waiting for next packet
                        BEQ     .UART_HANDLE_RX
                        BRA     .IS_FINAL         ; Branch even if status was 1 as this may be the last packet
            .IS_FINAL   CMPA    #2              ; Check if this is the final packet
                        BEQ     .UART_CLOSE_CONNECTION
                        BRA     .END_IF
            .END_IF     RTI

.UART_HANDSHAKE_BEGIN   LDAA    RX_REGISTER0
                        LDAB    RX_REGISTER1 
                        ABA     
                        STAA    TX_REGISTER
                        BRA     ACK_PULSE_BYTE
                        LDAA    #1
                        RTS     

.UART_HANDLE_RX         LDX     RX_BUFFER_START
                        BRA     READ_RX_BUFFER
                        LDAA    0,X             ; Simply echo the byte back (ignore MS byte)
                        BRA     TX_BYTE
                        BRA     STORE_PACKET
                        BRA     .LAST_PACKET_CHECK
                        RTS
.LAST_PACKET_CHECK      LDAA    #255            ; Have we read 255 packets yet?
                        CMPA    PACKET_COUNT
                        BEQ     .SET_LAST_PACKET
                        RTS
.SET_LAST_PACKET        LDAA    #2
                        STAA    UART_STATUS
                        RTS

.UART_CLOSE_CONNECTION  COM     UART_STATUS     ; Complement (set negative) the status byte
                        SEI                     ; Disable interupts (set interupt mask)

STORE_PACKET            LDX     RX_BUFFER_START
                        LDAA    0,X
                        LDAB    1,X
                        LDX     USER_CODE_START
                        STAA    
                        
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
