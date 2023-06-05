
; -----------------------------------
; Will attempt to read the data recieved (into SIPO 0) and then echo it back (through tx PISO)
; -----------------------------------
; Target: MC680x with SC1 layout (see hardware/layouts)
; Assembler: SBASM v3 
; -----------------------------------

            
            .CR    6800                ; Select cross overlay (Motorola 6802)
            .OR    $E000               ; The program will start at address $8000 
            .TF    blink.hex, BIN        ; Set raw binary output
            
            ;.LI   TON                   ;  Turn timing information on
; Macros (expanded by assembler)
SET_PORT_MODE  .MA      A_MODE,B_MODE
                LDAA    #%0000.0100
                STAA    PIA_CON_A
                STAA    PIA_CON_B
                LDAA    ]1
                STAA    PIA_A
                LDAB    ]2
                STAB    PIA_B
                CLRA
                STAA    PIA_CON_A
                STAA    PIA_CON_B
                LDAA    ]1
                STAA    PIA_A
                STAB    PIA_B
                LDAA    #%0000.0100     ; Select data registers again
                STAA    PIA_CON_A
                STAA    PIA_CON_B
               .EM

INIT_UART           .MA     
                LDAB    #UART_RESET_BITS    ; Reset the ACIA
                STAB    UART_CONTROL
                NOP
                >DISABLE_TX_IRQ
                    .EM              

DISABLE_TX_IRQ  .MA
                LDAB    #UART_BAUD_X16      ; Set ACIA clk divisor (x16)
                ORAB    #UART_MODE_BITS     ; Set mode bits (8n1)
                ORAB    #UART_RX_IRQ_BIT    ; Enable RX interupts
                STAB    UART_CONTROL        ; Store to ACIA's register
                .EM
ENABLE_TX_IRQ  .MA
                LDAB    #UART_BAUD_X16      ; Set ACIA clk divisor (x16)
                ORAB    #UART_MODE_BITS     ; Set mode bits (8n1)
                ORAB    #UART_RX_IRQ_BIT    ; Enable RX interupts
                ORAB    #UART_TX_IRQ_BIT    ; and TX interupts
                STAB    UART_CONTROL        ; Store to ACIA's register
                .EM
;------------------------------------------------------------------------
;  Address lables
;------------------------------------------------------------------------
; --- Internal/zero page allocated address & locations
STACK_PTR_IR_L  .EQ     $00             ; Byte 0 & 1 of internal RAM are used to backup stack pointer during interupts
INDEX_PTR_IR_L  .EQ     $02             ; and 2 & 3, the index pointer (during IRQ)
STACK_PTR_GB_L  .EQ     $04             ; 4 & 5 general purpose stack pointer backup
INDEX_PTR_GB_L  .EQ     $06             ; 6 & 7 general purpose index pointer backup
MESSAGE_INDEX   .EQ     $08             ; 8 & 9 used to point to next char of ROM message
IPTR_DELAY_L    .EQ     $0A           ; Used to back up X during delay subroutine
DELAY_SEL_LOW   .EQ     $0C           ; Number of clock cycles for delay sr (low byte, high byte = +1)
USER_CODE_HEADL .EQ     $0E           ; point to the last user_code entry (0xE & 0xF) 
PORT_A_DATA     .EQ     $10           ; Buffers the data to be sent to & that is read from PIA port A
PORT_B_DATA     .EQ     $11           ;                                                        &    B

TX_BUFFER_TAIL  .EQ     $12           ; 12 & 13 point to next free location in TX buffer - write/input
TX_BUFFER_HEAD  .EQ     $14           ; 14 & 15 point to the next byte to be sent over UART - read/output
                                      ; if TAIL==HEAD then there are no pending bytes

TX_BUFFER_START .EQ     $1A                 ; 64 bytes of UART TX buffer (26)
TX_BUFFER_END   .EQ     $5A                 ; end of UART-TX buffer      (90)
 
; --- PIA registers (start at 0x80)
PIA_A           .EQ     $8000           ; Pia data register A 
PIA_B           .EQ     $8001           ; Pia data register B 
PIA_CON_A       .EQ     $8002           ; Pia control register A
PIA_CON_B       .EQ     $8003           ; Pia control register B

; --- 6850 ACIA (UART) registers
UART_CONTROL    .EQ     $8004        ; R: Status register,  W: Control register
UART_DATA       .EQ     $8005        ; R: RX data register, W: TX data register

; --- Far-page ext SRAM 
PAGE_ONE_TOP    .EQ     $1000
PAGE_ONE_START  .EQ     $0800

USER_CODE_START .EQ     PAGE_ONE_TOP - 1    ; ~1.9kb USER_CODE
USER_CODE_END   .EQ     PAGE_ONE_START      ; The limit on UC space
;------------------------------------------------------------------------
; --- Labels used as constants (not addresses!) ---
;------------------------------------------------------------------------
DELAY_BASE      .EQ     12500         ; ~100ms of clock cycles 
UC_EMPTY_FLAG   .EQ     $FF           ; Value written during USERCODE_ERASE subroutine



;------------------------------------------------------------------------
;  Reset subroutine
;------------------------------------------------------------------------

RESET           LDS     #$7F                        ; Reset stack pointer
                LDX     #DELAY_BASE                 ; Set the delay to default at 100ms 
                STX     DELAY_SEL_LOW  
                ; Reset pointers
                LDX     #USER_CODE_START            ; User code last entry/head pointer
                STX     USER_CODE_HEADL             
                LDX     #TX_BUFFER_START            ; UART TX buffer I/O pointers
                STX     TX_BUFFER_TAIL
                STX     TX_BUFFER_HEAD             
                
                >SET_PORT_MODE  #%1111.1111,#%1111.1111 ; PIA PA0-7 & PB0-7 all output 
                CLRA
                STAA    PORT_A_DATA
                STAA    PORT_B_DATA
                
                JMP     MAIN                        ; Begin MAIN subroutine

MAIN            LDAA    PORT_B_DATA
                INCA
                STAA    PORT_B_DATA
                STAA    PIA_B                     ; Enable ACIA TX interupts as there is now data waiting to be sent
                BSR     DELAY                       ; 100ms delay between each char
                BRA     MAIN                        ; Jump to start of MAIN subroutine and repeat


; Delay subroutine
DELAY           LDX    DELAY_SEL_LOW       ; Set delay counter and count down
.LOOP           DEX                        ; to 0
                BNE    .LOOP               ; Not 0 yet!
                RTS



;------------------------------------------------------------------------
;  Interrupt and reset vectors
;   These bytes point to the locations of subroutines called during hardware events:
;   - IRQ:   LOW pulse on IRQ pin IF interupt mask bit unset (maskable interupt)
;   - SWI:   Execution of SWI instruction (software interupt)
;   - NMI:   LOW pulse on NMI pin regardless of interupt mask state (non-maskable interupt)
;   - Reset: called after system boot and/or LOW pulse on ~RST pin
;   Big endian: High byte stored first (eg: 0xFFFE 0xFFFF points to HI(reset) LO(reset))
;------------------------------------------------------------------------

                .NO     $FFF8,$FF
                .DA     RESET      ; IRQ 
                .DA     RESET      ; SWI 
                .DA     RESET      ; NMI 
                .DA     RESET            ; Reset
