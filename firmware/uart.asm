
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
USER_CODE_HEADL .EQ     $0E           ; point to the last user_code entry (0xE & 0xF) 
PORT_A_DATA     .EQ     $10           ; Buffers the data to be sent to & that is read from PIA port A
PORT_B_DATA     .EQ     $11           ;                                                        &    B

TX_BUFFER_TAIL  .EQ     $12           ; 12 & 13 point to next free location in TX buffer - write/input
TX_BUFFER_HEAD  .EQ     $14           ; 14 & 15 point to the next byte to be sent over UART - read/output
                                      ; if TAIL==HEAD then there are no pending bytes

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
TX_BUFFER_END   .EQ     PAGE_ONE_TOP - 1    ; end of UART-TX buffer here
USER_CODE_START .EQ     PAGE_ONE_TOP - 65   ; ~1.9kb USER_CODE
USER_CODE_END   .EQ     PAGE_ONE_START      ; The limit on UC space
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
                LDX     #USER_CODE_START            ; User code last entry/head pointer
                STX     USER_CODE_HEADL             
                LDX     #TX_BUFFER_START            ; UART TX buffer I/O pointers
                STX     TX_BUFFER_TAIL
                STX     TX_BUFFER_HEAD             
                LDX     #MESSAGE_DATA               ; ROM message index/pointer, start at first char
                STX     MESSAGE_INDEX

                >SET_PORT_MODE  #%1111.1111,#%1111.1111 ; PIA PA0-7 & PB0-7 all output 
                CLRA
                STAA    PORT_A_DATA
                STAA    PORT_B_DATA
                >INIT_UART                          ; Setup ACIA for UART comms
                CLI                                 ; Enable interupts
                JMP     MAIN                        ; Begin MAIN subroutine

MAIN            LDX     MESSAGE_INDEX               ; Load pointer to next char of ROM message into X
                LDAA    0,X                         ; Read the char into acc A
                INX                                 ; Seek next char
                CPX     #MESSAGE_DATA_END           ; Check if we have reached end of data
                BNE     .STORE_MSG_IDX              ; If not skip to .STORE_MSG_IDX
                LDX     #MESSAGE_DATA               ; Wrap to message begining
.STORE_MSG_IDX  STX     MESSAGE_INDEX               ; Save X (next char ptr) to RAM
                LDX     TX_BUFFER_TAIL              ; Load ptr of TX buffer next free slot (tail)
                STAA    0,X                         ; Append the next char from ROM message to TX buffer
                INX                                 ; Seek next position within TX buffer
                CPX     #TX_BUFFER_END              ; Have we reached end of buffer's RAM space?
                BNE     .STORE_TX_PTR               ; If not skip to .STORE_TX_PTR
                LDX     #TX_BUFFER_START            ; Wrap to start of TX buffer (as it is a circular buffer)
.STORE_TX_PTR   STX     TX_BUFFER_TAIL              ; Save X (tx buffer tail ptr) to RAM
                >ENABLE_TX_IRQ                      ; Enable ACIA TX interupts as there is now data waiting to be sent
                BSR     DELAY                       ; 100ms delay between each char
                BRA     MAIN                        ; Jump to start of MAIN subroutine and repeat


; Delay subroutine
DELAY           LDX    DELAY_SEL_LOW       ; Set delay counter and count down
.LOOP           DEX                        ; to 0
                BNE    .LOOP               ; Not 0 yet!
                RTS

; Sub routine to execute usercode
EXEC_USERCODE   SEI
                CLR     >PIA_A              ; Clear PIA outputs
                CLR     >PIA_B              
                LDAA    #UART_RESET_BITS    ; Reset ACIA
                STAA    UART_CONTROL
                LDX     USER_CODE_HEADL     ; Load the address of first instruction
                JMP     0,X                 ; Begin execution

; Simple error indicator subroutine (fatal/non recoverable)
FATAL_ERR_LOOP  SEI                         ; Only NMA or reset can escape fatal error loop
                LDAA    #%1000.0000
.LOOP           RORA                        ; right rotate (bit shift) acc A through carry - results in a single bit cyclically moving right then wrapping 
                STAA    PIA_B               ; Output on PIA port B leds (to "indicate" fatal error to user)
                LDAB    #$FF                ; Short delay using acc B (start at 0xFF, decrement (with NOP) until 0 then continue)
.DELAY          DECB                        ; Decrement acc B
                NOP                         ; NOP takes 2 clock cycles
                BNE     .DELAY              ; If zero bit not set (from DECB operation) repeat by branch to .DELAY
                BRA     .LOOP               ; Otherwise, repeat by branching to .LOOP

;------------------------------------------------------------------------
; Interupt handlers
;------------------------------------------------------------------------

; IRQ/ maskable handler
IRQ_HANDLER     SEI                         ; Disable futher IRQ while processing this one
                STS     STACK_PTR_IR_L      ; Backup stack & index pointers
                STX     INDEX_PTR_IR_L      ; We are now free to use them ourselves
                LDAA    UART_CONTROL        ; Read ACIA status register
                BITA    #UART_RX_STATUS     ; Check if there is a byte pending reading from ACIA
                BEQ     .UART_TX_TEST       ; If not skip to .UART_TX_TEST 
                LDX     USER_CODE_HEADL     ; Load ptr of next unwritten usercode byte into X       
                LDAB    UART_DATA           ; Read byte from ACIA into acc B
                STAB    0,X                 ; Append byte to user code
                DEX                         ; Seek next UC entry location
                CPX     #USER_CODE_END      ; Check if we have reached end of allocated RAM for UC
                BEQ     .UCODE_OVERFLOW     ; If so, handle this (as considered error condition)
                STX     USER_CODE_HEADL     ; Save X (ptr of most recent UC entry) to RAM
.UART_TX_TEST   BITA    #UART_TX_STATUS     ; Check if ACIA indicates TX ready
                BEQ     .UART_TST_END       ; If not, then skip to .UART_TST_END
                LDX     TX_BUFFER_HEAD      ; Load ptr of next byte awaiting TX in UART TX buffer
                CPX     TX_BUFFER_TAIL      ; Check if there is no unsent bytes in buffer (tail==head)
                BEQ     .DISABLE_TX_IRQ     ; If so (no unsent bytes), skip to .DISABLE_TX_IRQ
                LDAB    1,X                 ; Otherwise, load char into acc B (head+1)
                STAB    UART_DATA           ; And send to ACIA TX register
                STAB    PIA_B               ; Also output on LEDs as visual confirmation
                INX                         ; Seek next buffer location
                CPX     #TX_BUFFER_END      ; Check if we have reached end of allocated memory
                BNE     .STORE_TX_PTR       ; If not, skip to .STORE_TX_PTR
                LDX     #TX_BUFFER_START    ; Wrap to start of allocated memory (tx buffer is circular)
.STORE_TX_PTR   STX     TX_BUFFER_HEAD      ; Save X (tx buff head ptr) to RAM
                BRA     .UART_TST_END       ; Skip disabling TX interupts if we just sent a char
.DISABLE_TX_IRQ >DISABLE_TX_IRQ             ; Disable TX ready interupts from ACIA if no chars pending TX

.UART_TST_END   CLRA                        ; Done with ACIA status word, clear acc A
.DONE           LDX     INDEX_PTR_IR_L      ; Return stack & index pointers to inital state
                LDS     STACK_PTR_IR_L      
                CLI                         ; Unset interupt flag/re-enable future IRQs
                RTI                         ; Return from interupt      
; Error handlers for IRQ handler
.UCODE_OVERFLOW JMP     FATAL_ERR_LOOP      ; TODO: better handling of user code overflow

; NMI (non-maskable) handler (Here, triggers a reset/unused)
NMI_HANDLER     JMP     RESET

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
                .DA     NMI_HANDLER      ; NMI 
                .DA     RESET            ; Reset
