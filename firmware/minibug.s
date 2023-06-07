* MINI-BUG
* COPYWRITE 1973, MOTOROLA INC
* REV 004 (USED WITH MIKBUG)

ACIACS EQU    $8004   ACIA CONTROL/STATUS
ACIADA EQU    ACIACS+1
ARESET EQU    %00000011     Written to ACIA for reset
ACONF  EQU    %00010101     No Rx/Tx IRQ, 8n1 UART @ 31250 baud (16x clk divisor + external 2x)
*      
       ORG    $0000
       FCC    "CORNputer CMON online"     ; Remove if not creating disk image for simulator

       ORG    $1000
       RMB    4096
STACK  RMB    1        STACK POINTER
* REGISTERS FOR GO
       RMB    1        CONDITION CODES
       RMB    1        B ACCUMULATOR
       RMB    1        A
       RMB    1        X-HIGH
       RMB    1        X-LOW
       RMB    1        P-HIGH
       RMB    1        P-LOW
SP     RMB    1        S-HIGH
       RMB    1        S-LOW
* END REGISTERS FOR GO
CKSM   RMB    1        CHECKSUM
BYTECT RMB    1        BYTE COUNT
XHI    RMB    1        XREG HIGH
XLOW   RMB    1        XREG LOW
* Pointers used for printing a string
STRS   RMB    2        Pointer to start of string (16 bit)
STRE   RMB    2        Pointer to end of string (16 bit)
IOV    RMB    2        IO INTERRUPT POINTER
BEGA   RMB    2        BEGINING ADDR PRINT/PUNCH
ENDA   RMB    2        ENDING ADDR PRINT/PUNCH
NIO    RMB    2        NMI INTERRUPT POINTER
TEMP   RMB    1        CHAR COUNT (INADDR)
TW     RMB    2        TEMP/
MCONT  RMB    1        TEMP
XTEMP  RMB    2        X-REG TEMP STORAGE

* Begin EEPROM/code space
       ORG    $E000
* INPUT ONE CHAR INTO A-REGISTER
INCH   LDAA  ACIACS
       ASRA
       BCC    INCH     RECEIVE NOT READY
       LDAA  ACIADA   INPUT CHARACTER
       ANDA  #$7F     RESET PARITY BIT
       CMPA  #$7F
       BEQ    INCH     RUBOUT IGNORE
       JMP    OUTCH    ECHO CHAR

* INPUT HEX CHAR
INHEX  BSR    INCH
       CMPA  #$30
       BMI    C1       NOT HEX
       CMPA  #$39
       BLE    IN1HG
       CMPA  #$41
       BMI    C1       NOT HEX
       CMPA  #$46
       BGT    C1       NOT HEX
       SUBA  #7
IN1HG  RTS

LOAD   LDAA  #@21
       BSR    OUTCH

LOAD3  BSR    INCH
       CMPA  #'S
       BNE    LOAD3    1ST CHAR NOT (S)
       BSR    INCH
       CMPA  #'9
       BEQ    LOAD21
       CMPA  #'1
       BNE    LOAD3    2ND CHAR NOT (1)
       CLR    CKSM     ZERO CHECKSUM
       BSR    BYTE     READ BYTE
       SUBA  #2
       STAA  BYTECT   BYTE COUNT
* BUILD ADDRESS
       BSR    BADDR
* STORE DATA
LOAD11 BSR    BYTE
       DEC    BYTECT
       BEQ    LOAD15   ZERO BYTE COUNT
       STAA  0,X        STORE DATA
       INX
       BRA    LOAD11

LOAD15 INC    CKSM
       BEQ    LOAD3
LOAD19 LDAA  #'?      PRINT QUESTION MARK
       BSR    OUTCH
LOAD21 LDAA  #$B1     TURN READER OFF
       STAA  ACIACS
       LDAA  #@23
       BSR    OUTCH
C1     JMP    CONTRL

* BUILD ADDRESS
BADDR  BSR    BYTE     READ 2 FRAMES
       STAA  XHI
       BSR    BYTE
       STAA  XLOW
       LDX    XHI      (X) ADDRESS WE BUILT
       RTS

* INPUT BYTE (TWO FRAMES)
BYTE   BSR    INHEX    GET HEX CHAR
       ASLA
       ASLA
       ASLA
       ASLA
       TAB
       BSR    INHEX
       ANDA  #$0F     MASK TO 4 BITS
       ABA
       TAB
       ADDB  CKSM
       STAB  CKSM
       RTS

* CHANGE MEMORY (M AAAA DD NN)
CHANGE BSR    BADDR    BUILD ADDRESS
       BSR    OUTS     PRINT SPACE
       BSR    OUT2HS
       BSR    BYTE
       DEX
       STAA 0,X
       CMPA 0,X
       BNE    LOAD19   MEMORY DID NOT CHANGE
       BRA    CONTRL

OUTHL  LSRA           OUT HEX LEFT BCD DIGIT
       LSRA
       LSRA
       LSRA

OUTHR  ANDA  #$F      OUT HEX RIGHT BCD DIGIT
       ADDA  #$30
       CMPA  #$39
       BLS    OUTCH
       ADDA  #$7

* OUTPUT ONE CHAR
OUTCH  PSHB           SAVE B-REG
OUTC1  LDAB  ACIACS
       ASRB
       ASRB
       BCC    OUTC1    XMIT NOT READY
       STAA  ACIADA   OUTPUT CHARACTER
       PULB
       RTS

OUT2H  LDAA  0,X      OUTPUT 2 HEX CHAR
       BSR    OUTHL    OUT LEFT HEX CHAR
       LDAA  0,X
       BSR    OUTHR    OUT RIGHT HEX VHAR
       INX
       RTS

OUT2HS BSR    OUT2H    OUTPUT 2 HEX CHAR + SPACE
OUTS   LDAA  #$20     SPACE
       BRA    OUTCH    (BSR & RTS)

     
* PRINT CONTENTS OF STACK
PRINT  TSX
       STX    SP       SAVE STACK POINTER
       LDAB  #9
PRINT2 BSR    OUT2HS   OUT 2 HEX & SPCACE
       DECB
       BNE    PRINT2
       JMP    CONTRL

CONTRL LDS    #STACK   SET STACK POINTER
       LDAA   #$0d     CR
       BSR    OUTCH
       LDAA   #$0a     LF
       BSR    OUTCH    
       LDAA   #'>       > char
       BSR    OUTCH         
       BSR    OUTS

       JSR    INCH     READ CHARACTER
       TAB
       BSR    OUTS     PRINT SPACE
       CMPB  #'L
       BNE    *+5
       JMP    LOAD
       CMPB  #'M
       BEQ    CHANGE
       CMPB  #'R
       BEQ    PRINT    STACK
       CMPB  #'A
       BEQ    OUTMBS
       CMPB  #'P
       BEQ    PUNCH
       CMPB  #'G
       BNE    CONTRL
       RTI             GO

OUTSTR LDX    STRS
       LDAA   0,X
       INX
       CPX    STRE
       BEQ    OSDONE
       STX    STRS
       JSR    OUTCH
       BRA    OUTSTR
OSDONE RTS

OUTMBS LDX    #ASCII_FRACTAL_ST
       STX    STRS
       LDX    #ASCII_FRACTAL_EN
       STX    STRE
       BSR    OUTSTR
       JMP    CONTRL

* ENTER POWER ON SEQUENCE
START  EQU    *
       LDS    #STACK   SET STACK POINTER
       LDAA  #ARESET     Reset ACIA
       STAA  ACIACS
       NOP
       LDAA  #ACONF      Set up ACIA
       STAA  ACIACS
* Print bootmessage
       LDX    #BOOT_STR_START
       STX    STRS
       LDX    #BOOT_STR_END
       STX    STRE
       BSR    OUTSTR
       JMP    CONTRL

* PRINT DATA POINTED AT BY X-REG
PDATA2 JSR    OUTCH
       INX
PDATA1 LDAA   0,X
       CMPA   #4
       BNE    PDATA2
       RTS             STOP ON EOT

PUNCH  EQU    *

       LDAA   #$12     TURN TTY PUNCH ON
       JSR    OUTCH    OUT CHAR

       LDX    BEGA
       STX    TW       TEMP BEGINING ADDRESS
PUN11  LDAA   ENDA+1
       SUBA   TW+1
       LDAB   ENDA
       SBCB   TW
       BNE    PUN22
       CMPA   #16
       BCS    PUN23
PUN22  LDAA   #15
PUN23  ADDA   #4
       STAA   MCONT    FRAME COUNT THIS RECORD
       SUBA   #3
       STAA   TEMP     BYTE COUNT THIS RECORD
*     PUNCH C/R,L/F,NULL,S,1
       LDX    #MTAPE1
       JSR    PDATA1
       CLRB            ZERO CHECKSUM
*     PUNCH FRAME COUNT
       LDX    #MCONT
       BSR    PUNT2    PUNCH 2 HEX CHAR
*     PUNCH ADDRESS
       LDX    #TW
       BSR    PUNT2
       BSR    PUNT2
*     PUNCH DATA
       LDX    TW
PUN32  BSR    PUNT2    PUNCH ONE BYTE (2 FRAMES)
       DEC    TEMP     DEC BYTE COUNT
       BNE    PUN32
       STX    TW
       COMB 
       PSHB 
       TSX
       BSR    PUNT2    PUNCH CHECKSUM
       PULB 
       LDX    TW
       DEX
       CPX    ENDA
       BNE    PUN11
       JMP    CONTRL       

*     PUNCH 2 HEX CHAR, UPDATE CHECKSUM
PUNT2  ADDB   0,X      UPDATE CHECKSUM
       JMP    OUT2H    OUTPUT TWO HEX CHAR AND RTS

MCLOFF FCB    $13      READER OFF
MCL    FCB    $D,$A,$14,0,0,0,'*,4   C/R,L/F,PUNCH
       RTS

CATCH  JMP    CONTRL           Capture any stray PC so they dont try to execute the ASCII art :-)

MTAPE1 FCB    $D,$A,0,0,0,0,'S,'1,4   PUNCH FORMAT

ASCII_FRACTAL_ST
       FCC     "                                  "
       FCB    $0D,$0A  CRLF
       FCC     "                                  \\"
       FCB    $0D,$0A  CRLF
       FCC     "                                  `\,/"
       FCB    $0D,$0A  CRLF
       FCC     "                                  .-'-."
       FCB    $0D,$0A  CRLF
       FCC     "                                 '     `"
       FCB    $0D,$0A  CRLF
       FCC     "                                 `.   .'"
       FCB    $0D,$0A  CRLF
       FCC     "                          `._  .-~     ~-.   _,'"
       FCB    $0D,$0A  CRLF
       FCC     "                           ( )'           '.( )"
       FCB    $0D,$0A  CRLF
       FCC     "             `._    _       /               .'"
       FCB    $0D,$0A  CRLF
       FCC     "              ( )--' `-.  .'                 ;"
       FCB    $0D,$0A  CRLF
       FCC     "         .    .'        '.;                  ()"
       FCB    $0D,$0A  CRLF
       FCC     "          `.-.` CORNELIUS '                 .'"
       FCB    $0D,$0A  CRLF
       FCC     "----*-----;      T E C H N O L O G I E S   .'"
       FCB    $0D,$0A  CRLF
       FCC     "          .`-'.           ,                `."
       FCB    $0D,$0A  CRLF
       FCC     "         '    '.        .';                  ()"
       FCB    $0D,$0A  CRLF
       FCC     "              (_)-   .-'  `.                 ;"
       FCB    $0D,$0A  CRLF
       FCC     "             ,'   `-'       \               `."
       FCB    $0D,$0A  CRLF
       FCC     "                           (_).           .'(_)"
       FCB    $0D,$0A  CRLF
       FCC     "                          .'   '-._   _.-'    `."
       FCB    $0D,$0A  CRLF
       FCC     "                                 .'   `."
       FCB    $0D,$0A  CRLF
       FCC     "                                 '     ;"
       FCB    $0D,$0A  CRLF
       FCC     "                                  `-,-'"
       FCB    $0D,$0A  CRLF
       FCC     "                                   /`\\"
       FCB    $0D,$0A  CRLF
       FCC     "                                 /`"
       FCB    $0D,$0A  CRLF
ASCII_FRACTAL_EN

BOOT_STR_START
       FCC    "-- Cornelius Technologies --"
       FCB    $0D,$0A  CRLF
       FCC    "CMON v1.0.1"
       FCB    $0D,$0A  CRLF
BOOT_STR_END

* ASCII art in ROM
* ROM vectors 
       ORG    $FFF8
SWIVEC FDB    PRINT         Software interupt (triggers stack print)
IRQVEC FDB    PRINT         Maskable (IRQ) interupt (triggers IRQ subroutine)
NMIVEC FDB    START         Non-maskable (NMI) interupt (triggers reset/bootup)
RSTVEC FDB    START         Reset event (triggers bootup)
       END
