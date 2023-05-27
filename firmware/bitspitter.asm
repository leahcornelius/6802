
; -----------------------------------
; Will load a string (or any data really) from the start of ROM
; This is put onto the "top" of the stack (here the top of page 1 SRAM)
; It will then shift the data out, bit by bit on PB2
; Each bit is rising edge clocked by PB3
; Framing of each byte is done on PB4 - pulsed high for two clock (PB3 not CPU)
; cycles at the start and end of each byte. Aditionally at the end of each byte 
; (after the above) it is kept high for 2 more clk pulses/cycles)
; During the transmission of a frame it remains low
; The baudrate is set by the lable "BAUD_RATE_DELAY" - there will be a delay of
; 100 x BAUD_RATE_DELAY mS (milisecconds) after each bit/ per clock pulse
;
; The transmission begins ~300ms after the processor is reset (START_TX_DELAY label)
; and once all data has been sent enters a "standbye" loop until reset or an interupt recieved (todo)
; -----------------------------------
; Target: MC680x with SC1 layout (see hardware/layouts)
; Assembler: SBASM v3 
; -----------------------------------

            
            .CR    6800                ; Select cross overlay (Motorola 6802)
            .OR    $8000               ; The program will start at address $8000 
            .TF    bitspit.hex, BIN        ; Set raw binary output
            
            ;.LI   OFF                  
            
;------------------------------------------------------------------------
;  Declaration of constants
;------------------------------------------------------------------------
; - String data to send
MESSAGE_DATA    .DB     "Hello world, it is I",0
MESSAGE_DATA_END
                .DA     #0

MESSAGE_LENGTH  .EQ     MESSAGE_DATA_END - MESSAGE_DATA




STACK_POINTER_L .EQ     $00             ; Byte 0 & 1 of internal RAM are used to backup stack pointer
USER_CODE_END_L .EQ     $02             ; 2 & 3 point to the last user_code entry 
DELAY_ITERS     .EQ     $04          ; Number of 100ms delays for DELAY_LOOP
PORT_A_MODE     .EQ     $05           ; Stores the mode of port A's pins (I/O)
PORT_B_MODE     .EQ     $06           ;                  & port B
PORT_A_DATA     .EQ     $07           ; Buffers the data to be sent to & that is read from PIA port A
PORT_B_DATA     .EQ     $08           ;                                                        &    B
TX_BIT_INDEX    .EQ     $09           ; Indicates which bit we are currently txing

INDEX_POINTER_L .EQ     $0A           ; Used to back up X during delay subroutine
;   PIA registers (start at 0x80)
PIA_A           .EQ     $80           ; Pia data register A 
PIA_B           .EQ     $81           ; Pia data register B 
CON_A           .EQ     $82           ; Pia control register A
CON_B           .EQ     $83           ; Pia control register B

; Far-page ext SRAM 
PAGE_ONE_TOP    .EQ     $1000
PAGE_ONE_START  .EQ     $0800
USER_CODE_START .EQ     PAGE_ONE_TOP - 1

; Labels used as constants (not addresses)
DELAY_BASE      .EQ     12500         ; ~100ms of clock cycles 

; Bit masks for TX operations
TX_DATA         .EQ     %0000.0100
TX_CLK          .EQ     %0000.1000
TX_FRAME_CTRL   .EQ     %0001.0000

; Macros (expanded by assembler)
SET_PORT_MODE  .MA      A_MODE,B_MODE
                LDAA    #%0000.0100
                STAA    CON_A
                STAA    CON_B
                LDAA    ]1
                STAA    PIA_A
                LDAB    ]2
                STAB    PIA_B
                CLRA
                STAA    CON_A
                STAA    CON_B
                LDAA    ]1
                STAA    PIA_A
                STAB    PIA_B
                LDAA    #%0000.0100     ; Select data registers again
                STAA    CON_A
                STAA    CON_B
            .EM

WRITE_PORT_DATA_A   .MA     DATA   
                LDAA    ]1
                STAA    PIA_A
                    .EM
WRITE_PORT_DATA_B   .MA     DATA    
                LDAA    ]1
                STAA    PIA_B
                    .EM

CLOCK_PULSE         .MA     
                EORB    #TX_CLK
                STAB    PIA_B
                JSR     DELAY_100MS
            .EM

;------------------------------------------------------------------------
;  Start of program
;------------------------------------------------------------------------
LOAD_MSG_DATA   STS     >STACK_POINTER_L     ; Back up the stack pointer to RAM
                LDS     #PAGE_ONE_TOP-1
                LDX     #MESSAGE_DATA_END
.NEXT_BYTE      LDAA    0,X
                PSHA    
                DEX     
                CPX     #MESSAGE_DATA
                BNE     .NEXT_BYTE

                STS     >USER_CODE_END_L      ; Points to the last user code entry
                LDS     >STACK_POINTER_L      ; Return the stack to its inital state so we can return from subroutine
                RTS

RESET           LDS     #$7F                        ; Reset stack pointer
                >SET_PORT_MODE  #%1111.1111,#%1111.1111 ; PA2-PA7 input, PA0 & PA1 output. PB0-PB7 output (all)
                CLRA
                STAA    PORT_A_DATA
                STAA    PORT_B_DATA
                BSR     LOAD_MSG_DATA
                JSR     DELAY_100MS
                JMP     MAIN                

MAIN            LDX     #USER_CODE_START
                BSR     START_TX
.LOOP           NOP
.TX_BYTE        BSR     START_FRAME
                LDAA    0,X
                LDAB    #8                  ; There are 8 bits in a byte, keep track of them here
                STAB    TX_BIT_INDEX
.NEXT_BIT       CLRB
                ASLA                        ; Shift accA left - pushes next bit into status reg carry flag  
                BCC     .BIT_LOW            ; Skip setting tx bit if carry clear (bit was a 0)
                LDAB    #TX_DATA            ; Otherwise, set tx bit (in acc b)
.BIT_LOW        ORAB    #TX_CLK             ; Set tx clk bit high (OR acc B with #TX_CLK)
                STAB    PIA_B               ; Output on PIA
                JSR     DELAY_100MS          ; Wait for correct time for selected BAUD rate
                CLR     PIA_B               ; Clears entire port, ending clock pulse
                DEC     TX_BIT_INDEX
                BNE     .NEXT_BIT           ; Not on the last bit yet
                JSR     END_FRAME           ; TX_BIT_INDEX == 0 (entire byte txed)
                DEX
                CPX     USER_CODE_END_L     ; Check if we have reached the final user code entry
                BNE     .LOOP               ; If not, move to next byte
.DONE           BSR     END_TX              ; Otherwise end tx and then enter NOP loop until reset
                JMP     NOP_LOOP


START_TX        LDAB    #TX_FRAME_CTRL
                STAB    PIA_B
                LDAA    #7                 ; 7 clock cycles with CTRL high
.LOOP           >CLOCK_PULSE               ; H
                >CLOCK_PULSE               ; L
                DECA
                BNE     .LOOP
                CLRB    
                >CLOCK_PULSE               ; H
                >CLOCK_PULSE               ; L
                RTS

END_TX          CLR     PIA_B
                RTS

START_FRAME     CLRB
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                ORAB    #TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                EORB    #TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                EORB    #TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                EORB    #TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                RTS

END_FRAME       LDAB    #TX_FRAME_CTRL
                ORAB    #TX_CLK
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                EORB    #TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                RTS                

; Delay utils
DELAY_100MS     STX    >INDEX_POINTER_L         ; Backup index pointer
                LDX    #DELAY_BASE              ; Set delay counter and count down
.LOOP           DEX                        ; to 0
                BNE    .LOOP               ; Not 0 yet!
                LDX    >INDEX_POINTER_L     ; Replace index pointer to backed up value
                RTS

NOP_LOOP        NOP
                BRA     NOP_LOOP                       
;------------------------------------------------------------------------
;  Interrupt and reset vectors
;------------------------------------------------------------------------

                .NO     $FFF8,$FF
                .DA     RESET            ; IRQ
                .DA     RESET            ; SWI (Not used)
                .DA     RESET            ; NMI (Not used)
                .DA     RESET            ; Reset
