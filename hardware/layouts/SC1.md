# SC1 layout
MC6802 CPU, MC6821 PIO, W27-C512 EEPROM, 2x UM6116 SRAM
## ROM
ROM provided by 64kb EEPROM, half addressed to provide 32kb addressable ROM. Active from 0x8000 upwards (!A15 -> CS).
This cannot be written to by the CPU, as it requires 14v/12v for erasure and programming. Instead use this for BIOS.
The BIOS provides a method to load a program from an external interface (ie UART) into RAM, which can then be branched to.

## RAM
Two 2kb SRAMs (um6116-2) are located between address 0x0800 and 0x2000. The first starts at 0x0800 and ends at 0x1000, without
any mirroring. The seccond starts at 0x1000 and is active all the way to 0x2000 - with mirroring every 2kb. Effective address range of the entire SRAM is 0x0800 through 0x1800 giving 4kb. 
### Internal
The 6802 has 128 bytes of internal SRAM located between 0x0 to 0x0080. 

## PIO
The MC6821 provides parralel input and output to the system. It has two 8-bit bi-directional ports (A & B).
The PIO's operation is set by the CPU using it's registers. Each port has a control register, used to set the states 
of the pins, and a data-direction register, used to set the mode of each pin (input or output).
The addresses of the PIO's four registers are:
| Register    	| Address 	|
|-------------	|---------	|
| DATA (A)    	| 0x0080  	|
| DATA (B)    	| 0x0081  	|
| CONTROL (A) 	| 0x0082  	|
| CONTROL (B) 	| 0x0083  	|

## CPU
### Interupts
Both interupt lines (NMI & IRQ) are pulled high by 3.3k resistors. 
### Clock
The 6802 is clocked by a 4mhz crystall oscilator connected to XTAL and EXTAL, with two 27pF ceramic capacitors between these pins and ground. The 6802 includes a 4x clock divisor internally and so this results in a clock frequency of 1MHz. 
