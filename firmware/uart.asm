
; -----------------------------------
; Will attempt to read the data recieved (into SIPO 0) and then echo it back (through tx PISO)
; -----------------------------------
; Target: MC680x with SC1 layout (see hardware/layouts)
; Assembler: SBASM v3 
; -----------------------------------

            
            .CR    6800                ; Select cross overlay (Motorola 6802)
            .OR    $8000               ; The program will start at address $8000 
            .TF    uart.hex, BIN        ; Set raw binary output
            
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
                LDAA    #UART_RESET_BITS    ; Reset the ACIA
                STAA    UART_CONTROL
                NOP
                >ENABLE_TX_IRQ
                    .EM              

DISABLE_TX_IRQ  .MA
                LDAA    #UART_BAUD_X16      ; Set ACIA clk divisor (x16)
                ORAA    #UART_MODE_BITS     ; Set mode bits (8n1)
                ORAA    #UART_RX_IRQ_BIT    ; Enable RX interupts
                STAA    UART_CONTROL        ; Store to ACIA's register
                .EM
ENABLE_TX_IRQ  .MA
                LDAA    #UART_BAUD_X16      ; Set ACIA clk divisor (x16)
                ORAA    #UART_MODE_BITS     ; Set mode bits (8n1)
                ORAA    #UART_RX_IRQ_BIT    ; Enable RX interupts
                ORAA    #UART_TX_IRQ_BIT    ; and TX interupts
                STAA    UART_CONTROL        ; Store to ACIA's register
                .EM
;------------------------------------------------------------------------
;  Data
;------------------------------------------------------------------------
; - String data to send
MESSAGE_DATA    .DB     "Hello world: motherfucking BOOM",0
MESSAGE_DATA_END
                .DA     $03

MESSAGE_LENGTH  .EQ     MESSAGE_DATA_END - MESSAGE_DATA

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
USER_CODE_END_L .EQ     $0E           ; point to the last user_code entry (this+1 should read 0) 
PORT_A_DATA     .EQ     $10           ; Buffers the data to be sent to & that is read from PIA port A
PORT_B_DATA     .EQ     $11           ;                                                        &    B

TX_BUF_IND_OUT  .EQ     $12           ; 12&13 point to last sent byte from TX buffer
TX_BUF_IND_IN   .EQ     $14           ; 14&15 point to the next free TX byte location - 1

LED_PATTERN     .EQ     $16           ; 16 holds 8 bit LED pattern for port B
; --- PIA registers (start at 0x80)
PIA_A           .EQ     $80           ; Pia data register A 
PIA_B           .EQ     $81           ; Pia data register B 
PIA_CON_A       .EQ     $82           ; Pia control register A
PIA_CON_B       .EQ     $83           ; Pia control register B

; --- 6850 ACIA (UART) registers
UART_CONTROL    .EQ     $3800        ; R: Status register,  W: Control register
UART_DATA       .EQ     $3801        ; R: RX data register, W: TX data register

; --- Far-page ext SRAM 
PAGE_ONE_TOP    .EQ     $1000
PAGE_ONE_START  .EQ     $0800
TX_BUFFER_START .EQ     PAGE_ONE_TOP - 64   ; 64 bytes of UART TX buffer
USER_CODE_START .EQ     PAGE_ONE_TOP - 65   ; ~1.9kb USER_CODE
USER_CODE_RANGE_MAX .EQ PAGE_ONE_START      ; The max end of USER code space
;------------------------------------------------------------------------
; --- Labels used as constants (not addresses!) ---
;------------------------------------------------------------------------
DELAY_BASE      .EQ     12500         ; ~100ms of clock cycles 
UC_EMPTY_FLAG   .EQ     $FF           ; Value written during USERCODE_ERASE subroutine

; UART controll register bits
UART_BAUD_X16   .EQ     %0000.0001    ; x16 divisor 
UART_RESET_BITS .EQ     %0000.0011    ; Resets the UART chip
UART_MODE_BITS  .EQ     %0001.0100    ; 8n1 (data/stop bits, parity) = 5
UART_TX_IRQ_BIT .EQ     %0010.0000    ; (En/Dis)able tx empty/ready interupts
UART_RX_IRQ_BIT .EQ     %1000.0000    ; (En/Dis)able rx buffer full interupts
; UART status register bits
UART_RX_STATUS  .EQ     %0000.0001    ; 0=no data, 1=data to be read
UART_TX_STATUS  .EQ     %0000.0010    ; 0=tx busy, 1=ready/can tx
UART_FRAME_ERR  .EQ     %0001.0000    ; RX frame error (1=error)
UART_OVER_ERR   .EQ     %0010.0000    ; RX overrun err (1=error)
UART_PARITY_ERR .EQ     %0100.0000    ; RX parity error (1=error)
UART_IRQ_STAUS  .EQ     %1000.0000    ; Interupt flag

; PIA bits
PIA_CX0_FLAG    .EQ     %1000.0000
;------------------------------------------------------------------------
;  Reset subroutine
;------------------------------------------------------------------------

RESET           LDS     #$7F                        ; Reset stack pointer
                LDX     #DELAY_BASE                 ; Set the delay to default at 100ms 
                STX     DELAY_SEL_LOW  
                ; Reset pointers
                LDX     #USER_CODE_START    ; User code end pointer
                STX     USER_CODE_END_L
                LDX     #TX_BUFFER_START     ; UART TX buffer I/O pointers
                STX     TX_BUF_IND_OUT
                STX     TX_BUF_IND_IN             
                LDX     #MESSAGE_DATA        ; ROM message index/pointer
                STX     MESSAGE_INDEX
                >SET_PORT_MODE  #%1111.1111,#%1111.1111 ; PA2-PA7 input, PA0 & PA1 output. PB0-PB7 output (all)
                CLRA
                STAA    PORT_A_DATA
                STAA    PORT_B_DATA
                >INIT_UART
                CLI                     ; Enable interupts
                JMP     MAIN    

MAIN            LDX     MESSAGE_INDEX
                LDAA    0,X
                INX     
                CPX     #MESSAGE_DATA_END    ; Check if we need to wrap back to start of msg
                BNE     .STORE_MSG_IDX
                LDX     #MESSAGE_DATA        ; Wrap to message begining
.STORE_MSG_IDX  STX     MESSAGE_INDEX       ; Save message index
                LDX     TX_BUF_IND_IN       
                INX
                CPX     #PAGE_ONE_TOP   
                BNE     .BUFFER_BYTE
                LDX     #TX_BUFFER_START    ; Wrap to start of tx buffer
.BUFFER_BYTE    STX     TX_BUF_IND_IN   
                STAA    0, X
                STAA    PIA_B
                BSR     DELAY
                >ENABLE_TX_IRQ          ; THere is now waiting data
                BRA     MAIN            ; Loop until reset


; Delay utils
DELAY           LDX    DELAY_SEL_LOW       ; Set delay counter and count down
.LOOP           DEX                        ; to 0
                BNE    .LOOP               ; Not 0 yet!
                RTS

INTERUPT        SEI                         ; Disable futher IRQ while processing this one
                STS     STACK_PTR_IR_L      ; Backup stack & index pointers
                STX     INDEX_PTR_IR_L      ; We are now free to use them ourselves
                LDAA    UART_CONTROL        ; Read ACIA status register
                BITA    #UART_RX_STATUS      ; Check if there is a byte pending reading from ACIA
                BEQ     .UART_TX_TEST       ; If not skip...
                LDS     USER_CODE_END_L     ; Set stack to next user code byte         
                LDAB    UART_DATA           ; Read data from ACIA
                PSHB
                STS     USER_CODE_END_L     ; Update user code index
.UART_TX_TEST   BITA    #UART_TX_STATUS      ; Check if it is time to send a byte from TX buffer
                BEQ     .PIA_TESTS         ; If not, then skip...
                LDX     TX_BUF_IND_OUT      ; Load the index of next byte to transmit
                CPX     TX_BUF_IND_IN       ; Check if the last byte has already been sent (in=out)
                BEQ     .DISABLE_TX_IRQ         ; No bytes pending tx, skip
                CPX     #PAGE_ONE_TOP-1     ; Check if we have reached the end of the buffer 
                BNE     .SKIP_WRAP_X
                LDX     #TX_BUFFER_START-1  ; We read +1 bytes from X so set this -1 when wraping
.SKIP_WRAP_X    LDAB    1,X                 
                STAB    UART_DATA
                INX         
                STX     TX_BUF_IND_OUT
.DISABLE_TX_IRQ >DISABLE_TX_IRQ
                CLRA
.PIA_TESTS      BRA     .DONE               ; Disable usercode erase & exec for now!!
; ----- start disabled! -------
.EXEC_TEST      LDAA    PIA_CON_A
                BITA    #PIA_CX0_FLAG        ; Check if CA0 high generated interupt
                BEQ     EXEC_USERCODE       ; If so execute code (doesnt return!)
                LDAA    PIA_CON_B           ; Check if CB2 high (clear code)
                BITA    #PIA_CX0_FLAG
                BNE     .DONE               ; If not skip                
.ERASE_USERCODE LDX     #USER_CODE_START
                STX     USER_CODE_END_L     ; Reset end pointer
                LDAA    #UC_EMPTY_FLAG      ; STAA 0,X faster than CLR 0,X (1 clk) so we set acc A to UC_EMPTY_FLAG then STAA 0,X to clear
.NEXT_BYTE      STAA    0,X                 ; Overwrite byte
                DEX                         
                CPX     #USER_CODE_RANGE_MAX ; Are we done yet?
                BNE     .NEXT_BYTE
; ----- end disabled! -------
.DONE           LDX     INDEX_PTR_IR_L     ; Return stack & index pointers to inital state
                LDS     STACK_PTR_IR_L      
                CLI                         ; Unset interupt flag/re-enable future IRQs
                RTI                         ; Return from interupt      

EXEC_USERCODE   SEI
                CLR     >PIA_A              ; Clear PIA outputs
                CLR     >PIA_B              
                LDAA    #UART_RESET_BITS    ; Reset ACIA
                STAA    UART_CONTROL
                LDX     USER_CODE_END_L     ; Load the address of first instruction
                JMP     0,X                 ; Begin execution

FATAL_ERR_LOOP  SEI                         ; Only NMA or reset can escape fatal error loop
                LDAA    #%1000.0000
.LOOP           RORA    
                STAA    PIA_B
                LDAB    #$FF
.DELAY          DECB     
                NOP
                BNE     .DELAY
                BRA     .LOOP



;------------------------------------------------------------------------
;  Interrupt and reset vectors
;------------------------------------------------------------------------

                .NO     $FFF8,$FF
                .DA     INTERUPT         ; IRQ
                .DA     RESET            ; SWI (Not used)
                .DA     RESET            ; NMI (Not used)
                .DA     RESET            ; Reset
