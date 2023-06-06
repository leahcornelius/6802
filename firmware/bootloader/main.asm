            .CR    6800                ; Select cross overlay (Motorola 6802)
            .OR    $E000               ; The program will start at address $8000 
            .TF    bootloader.hex, BIN ; Set raw binary output
            .IN    defines.lib
            .IN    std.lib
            .IN    macros.lib
            .IN    uart.lib

BOOT_MSG_STR    .DB     $0A,"> "
BOOT_MSG_END    .DA     $00                     ; End string

RESET           LDS     #$3FF                        ; Reset stack pointer
                LDX     #DELAY_BASE                 ; Set the delay to default at 100ms 
                STX     DELAY_SEL_LOW  
                ; Reset pointers
                LDX     #TX_BUFFER_START            ; UART TX buffer I/O pointers
                STX     TX_BUFFER_TAIL
                STX     TX_BUFFER_HEAD  
                LDX     #RX_BUFFER_START
                STX     RX_BUFFER_HEAD
                STX     RX_BUFFER_TAIL           
                >SET_PORT_MODE  #%1111.1111,#%1111.1111 ; PIA PA0-7 & PB0-7 all output 
                CLRA
                STAA    PORT_A_DATA
                STAA    PORT_B_DATA
                STAA    PIA_A
                STAA    PIA_B
                LDAA    #%0000.0001         ; Rx enabled
                STAA    UART_OPERATION
                
                LDAA    #UART_RESET_BITS    ; Reset the ACIA
                STAA    UART_CONTROL        
                ; Configure ACIA
                LDAA    #UART_BAUD_X16      ; Set ACIA clk divisor (x16)
                ORAA    #UART_MODE_BITS     ; Set mode bits (8n1)
                ORAA    #UART_RX_IRQ_BIT    ; Enable RX interupts
                STAA    UART_CONTROL        ; Store to ACIA's register
                CLI                         ; Enable interupts

                BSR     TX_BOOT_MSG         
                >ENABLE_TX_IRQ
                JMP     MAIN                        ; Begin MAIN subroutine
            
MAIN            LDX     RX_BUFFER_HEAD      ; Load rx buffer ptr into index register
                CPX     RX_BUFFER_TAIL      ; Check if there are any waiting bytes
                BEQ     .SKIP_RX            ; If not then skip
.RX_LOOP        LDX     RX_BUFFER_HEAD
                LDAA    0,X                 ; Read the next byte
                STAA    PIA_B               ; Show byte on leds
                ; - Echo byte back
                LDX     TX_BUFFER_TAIL      ; Load TX buffer ptr
                STAA    0,X                 ; Append byte to TX buffer
                DEX                         ; Seek next addr
                CPX     #TX_BUFFER_END      ; Check if we have reached the end of buffer
                BNE     .TX_NO_WRAP         ; If not skip
                LDX     #TX_BUFFER_START    ; Otherwise wrap to start of buffer
.TX_NO_WRAP     STX     TX_BUFFER_TAIL      ; Update tx buffer ptr in RAM
                ; Restore RX buffer ptr
                LDX     RX_BUFFER_HEAD
                DEX                         ; Seek next byte
                CPX     #RX_BUFFER_END      ; Check if we have reached end of RX buffer
                BNE     .RX_NO_WRAP         ; If not, skip...
                LDX     #RX_BUFFER_START    ; Wrap to start of buffer
.RX_NO_WRAP     STX     RX_BUFFER_HEAD      ; Update ptr in RAM
                CPX     RX_BUFFER_TAIL     ; Check if there are more bytes
                BNE     .RX_LOOP            ; There are, continue processing them
                >ENABLE_TX_IRQ              ; Enable TX IRQ (for echo chars)
.SKIP_RX        INC     PIA_A
                BRA     MAIN


TX_BOOT_MSG     LDX     #BOOT_MSG_STR       ; Load index ptr of first char
                STX     BOOT_MSG_IDX        ; Save to ram
.LOOP           LDAA    0,X                 ; Read char into acc A
                LDX     TX_BUFFER_TAIL
                STAA    0,X
                DEX     
                STX     TX_BUFFER_TAIL
                LDX     BOOT_MSG_IDX
                INX
                STX     BOOT_MSG_IDX
                CPX     #BOOT_MSG_END
                BNE     .LOOP
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
                .DA     IRQ_HANDLER      ; IRQ 
                .DA     IRQ_HANDLER      ; SWI 
                .DA     RESET             ; NMI 
                .DA     RESET            ; Reset
