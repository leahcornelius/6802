
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
            
            ;.LI   TON                   ;  Turn timing information on
            
;------------------------------------------------------------------------
;  Declaration of constants
;------------------------------------------------------------------------
; - String data to send
MESSAGE_DATA    .DB     "Hello world, it is I",0
MESSAGE_DATA_END
                .DA     #0

MESSAGE_LENGTH  .EQ     MESSAGE_DATA_END - MESSAGE_DATA


PIA_A           .EQ     $80           ; Pia data register A 
PIA_B           .EQ     $81           ; Pia data register B 
CON_A           .EQ     $82           ; Pia control register A
CON_B           .EQ     $83           ; Pia control register B

PORT_A_MODE     .EQ     $0004           ; Stores the mode of port A's pins (I/O)
PORT_B_MODE     .EQ     $0005           ;                  & port B
PORT_A_DATA     .EQ     $0006           ; Buffers the data to be sent to & that is read from PIA port A
PORT_B_DATA     .EQ     $0007           ;                                                        &    B

DELAY_ITERS     .EQ     $0001          ; Number of 100ms delays for DELAY_LOOP

PAGE_ONE_TOP    .EQ     $1000
PAGE_ONE_START  .EQ     $0800
USER_CODE_START .EQ     PAGE_ONE_START + 1
LOAD_RESULT     .EQ     $0008
TX_BIT_INDEX    .EQ     $0009

DELAY_BASE      .EQ     12500         ; ~100ms of clock cycles 
BAUD_RATE_DELAY .EQ     2             ; Delay/period of clock signal = BAUD_RATE_DELAY * 100 ms
START_TX_DELAY  .EQ     5               ; START_TX_DELAY * 100 ms wait before starting after reset

TX_DATA         .EQ     %0000.0100
TX_CLK          .EQ     %0000.1000
TX_FRAME_CTRL   .EQ     %0001.0000

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
                EORB    TX_CLK
                STAB    PIA_B
                BSR     DELAY_LOOP
            .EM

;------------------------------------------------------------------------
;  Reset and initialisation
;------------------------------------------------------------------------

RESET           LDS     #$7F          ; Reset stack pointer
                
                >SET_PORT_MODE  #%1111.1111,#%1111.1111 ; PA2-PA7 input, PA0 & PA1 output. PB0-PB7 output (all)
                CLRA
                STAA    PORT_A_DATA
                STAA    PORT_B_DATA
                BSR     LOAD_MSG_DATA
                LDAA    LOAD_RESULT
                CMPA    #0              ; Should be 0 if sucsessfuly read
                BNE     LOAD_FAIL       ; Otherwise loop until reset
                LDAA    #START_TX_DELAY
                STAA    DELAY_ITERS
                JSR     DELAY_LOOP
                LDX     #0
                

MAIN            LDX     0
                BSR     START_TX
.LOOP           BSR     TX_BYTE
                INX
                CPX     #MESSAGE_LENGTH
                BNE     .LOOP
.DONE           BSR     END_TX
.NOP_LOOP       NOP
                BRA     .NOP_LOOP


LOAD_MSG_DATA   LDX     MESSAGE_LENGTH
.READ_BYTE      LDAA    MESSAGE_DATA,X
                STAA    USER_CODE_START,X
                DEX     
                BNE     .READ_BYTE
                CLRA        
                STAA    LOAD_RESULT
                RTS

LOAD_FAIL       NOP   
.LOOP_OUTER     LDAA    #1
.LOOP_INNER     BSR     DELAY_100MS
                STAA    PIA_A
                ASLA
                BCC     .LOOP_INNER
                BSR     DELAY_100MS
                BRA     .LOOP_OUTER


START_TX        LDAA    #TX_FRAME_CTRL
                STAA    PIA_A
                RTS

END_TX          CLR     PIA_A
                RTS

START_FRAME     LDAB    BAUD_RATE_DELAY
                STAB DELAY_ITERS
                CLRB
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                ORAB    TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                EORB    TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                EORB    TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                EORB    TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                RTS

END_FRAME       LDAB    BAUD_RATE_DELAY
                STAB    DELAY_ITERS
                LDAB    TX_FRAME_CTRL
                ORAB    TX_CLK
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                EORB    TX_FRAME_CTRL
                >CLOCK_PULSE                ; H
                >CLOCK_PULSE                ; L
                RTS                

TX_BYTE         BSR     START_FRAME
                LDAA    BAUD_RATE_DELAY
                STAA    DELAY_ITERS
                LDAA    USER_CODE_START,X
                LDAB    #7
                STAB    TX_BIT_INDEX
.NEXT_BIT       CLRB
                ASLA    
                BCC     .BIT_LOW
                LDAB    TX_DATA
.BIT_LOW        ORAB    TX_CLK
                STAB    PIA_B
                BSR     DELAY_LOOP
                CLR     PIA_B
                DEC     TX_BIT_INDEX
                BNE     .NEXT_BIT
                BSR     END_FRAME
                RTS

; Delay utils
DELAY_100MS     LDX    #DELAY_BASE              ; Set delay counter and count down
.LOOP           DEX                        ; to 0
                BNE    .LOOP               ; Not 0 yet!
                RTS

DELAY_LOOP      LDAA   DELAY_ITERS
.LOOP           BSR    DELAY_100MS         ; Uses value in ram and completes that many 100ms delays
                DECA   
                BNE    .LOOP
                RTS
                        
;------------------------------------------------------------------------
;  Interrupt and reset vectors
;------------------------------------------------------------------------

                .NO     $FFF8,$FF
                .DA     RESET            ; IRQ
                .DA     RESET            ; SWI (Not used)
                .DA     RESET            ; NMI (Not used)
                .DA     RESET            ; Reset
