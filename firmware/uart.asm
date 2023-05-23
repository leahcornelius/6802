
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
            
;------------------------------------------------------------------------
;  Declaration of constants
;------------------------------------------------------------------------

PIA_A           .EQ     $80           ; Pia data register A 
PIA_B           .EQ     $81           ; Pia data register B 
CON_A           .EQ     $82           ; Pia control register A
CON_B           .EQ     $83           ; Pia control register B

PORT_A_MODE     .EQ     $0004           ; Stores the mode of port A's pins (I/O)
PORT_B_MODE     .EQ     $0005           ;                  & port B
PORT_A_DATA     .EQ     $0006           ; Buffers the data to be sent to & that is read from PIA port A
PORT_B_DATA     .EQ     $0007           ;                                                        &    B

DELAY_BASE      .EQ     12500         ; ~100ms of clock cycles 
DELAY_ITERS     .EQ     $0001          ; Number of 100ms delays for DELAY_LOOP

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

;------------------------------------------------------------------------
;  Reset and initialisation
;------------------------------------------------------------------------

RESET           LDS     #$007F          ; Reset stack pointer
                >SET_PORT_MODE  #%1111.1111,#%1111.1111 ; PA2-PA7 input, PA0 & PA1 output. PB0-PB7 output (all)
                LDAA    #10             ; Long delay of 1s (after overflow)
                STAA    DELAY_ITERS
                LDAA    #%1111.1111
                STAA    PORT_A_DATA
                CLRA
                STAA    PORT_B_DATA

MAIN            >WRITE_PORT_DATA_A PORT_A_DATA
                >WRITE_PORT_DATA_B PORT_B_DATA
                BSR     DELAY_100MS     ; Short delay between increments (always)
                INC     PORT_B_DATA    
                BVS     DELAY_LOOP      ; Long delay on pattern overflow
                BRA     MAIN            ; Loop until reset


; Delay utils
DELAY_100MS              LDX    #DELAY_BASE              ; Set delay counter and count down
.LOOP                    DEX                        ; to 0
                         BNE    .LOOP               ; Not 0 yet!
                         RTS

DELAY_LOOP               LDAA   DELAY_ITERS
.LOOP                    BSR    DELAY_100MS         ; Uses value in ram and completes that many 100ms delays
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
