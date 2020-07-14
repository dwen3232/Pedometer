; Kevin's accelerometer demo.
; Displays accelerometer data as a bubble level on the
; LEDs, similar to (but better than!) the default DE10-Lite demo.

ORG 0
	CALL   SetupI2C    ; Configure ADXL345
	
ReadLoop:
	CALL   ReadX       ; Get the X acceleration data
	OUT    Hex0        ; Display raw data
	
	; Manipuate the data to create a display on the LEDs.
	CALL   BubbleLevel
	
	JUMP   ReadLoop    ; Repeat forever

; BubbleLevel ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Nothing in here is really important to understand, but feel free to
; peruse if you like reverse-engineering assembly code.
;
; This subroutine takes a value (in AC when subroutine is called)
; and turns it into a "bubble level" display on the LEDs.  The
; display is dithered to increase the apparent resolution above
; the limited 10 LEDs.  That requires this subroutine to be called
; as frequently as possible (or at least ~240 Hz) to avoid flickering.
BubbleLevel:
	STORE  BblVal
	; Manipulation will be easier with positive numbers
	CALL   Abs
	STORE  BblPosVal
	
	; With current accelerometer settings, a value around 0x40 works well as
	; full-scale bubble movement.  There will be 3 bits of dither and the rest
	; of the bits of actual movement, so might as well separate those out now.
	LOADI  &B11111111000 ; Make a mask of bits for movement
	AND    BblPosVal   ; Get those bits of the value
	SHIFT  -3          ; Shift to be right-justified
	STORE  ShiftVal
	LOADI  &B0000111   ; Make a mask of 0b0000110
	AND    BblPosVal   ; Get those bits of the value
	STORE  DitherVal
	
	LOAD   MidBbl      ; Reset the bubble to the middle
	STORE  CurrBbl

	LOAD   DitherCnt
	ADDI   1
	STORE  DitherCnt   ; Increment the dither counter
	LOADI  &B111
	AND    DitherCnt
	STORE  DitherCnt   ; Keep count mod 8
	
	LOAD   BblVal
	JNEG   LeftShifts  ; Decide left or right based on sign
	JUMP   RightShifts
	
LeftShifts:
	; Exercise to the reader: do the shift with self-modifying code!
	LOAD   ShiftVal
	JZERO  LeftDither
	ADDI   -1
	STORE  ShiftVal
	LOAD   CurrBbl
	SHIFT  1
	STORE  CurrBbl
	JUMP   LeftShifts
LeftDither:
	; Depending on the low two bits, sometimes
	; do another shift to add dithering.
	LOAD   DitherVal
	SUB    DitherCnt
	JNEG   DisplayBbl
	JZERO  DisplayBbl
	LOAD   CurrBbl
	SHIFT  1
	STORE  CurrBbl
	JUMP   DisplayBbl

; Same as above, but the other direction	
RightShifts:
	LOAD   ShiftVal
	JZERO  RightDither
	ADDI   -1
	STORE  ShiftVal
	LOAD   CurrBbl
	SHIFT  -1
	STORE  CurrBbl
	JUMP   RightShifts
RightDither:
	LOAD   DitherVal
	SUB    DitherCnt
	JNEG   DisplayBbl
	JZERO  DisplayBbl
	LOAD   CurrBbl
	SHIFT  -1
	STORE  CurrBbl
	JUMP   DisplayBbl
	
DisplayBbl:
	; Display the result on the LEDs and return
	LOAD   CurrBbl
	OUT    LEDs
	RETURN
	
	
BblVal:    DW 0             ; Incoming data value
BblPosVal: DW 0             ; Absolute value of incoming data
MidBbl:    DW &B0000110000  ; Middle display for LEDs
CurrBbl:   DW &B0000110000  ; Current LED display
ShiftVal:  DW 0             ; Amount needed to shift
DitherVal: DW 0             ; Bits used for dither
DitherCnt: DW 0             ; Counter used for dithering

; Pause for 1/10 s
Delay:
	OUT    Timer
WaitingLoop:
	IN     Timer
	ADDI   -1
	JNEG   WaitingLoop
	RETURN

; Subroutine to configure the I2C for reading accelerometer data
; Only needs to be done once after each reset.
SetupI2C:
	LOAD   AccCfg      ; load the number of commands
	STORE  CmdCnt
	LOADI  AccCfg      ; Load list ADDRESS
	ADDI   1           ; Increment to first command
	STORE  CmdPtr
I2CCmdLoop:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CWCmd     ; load write command
	OUT    I2C_CMD     ; to I2C_CMD register
	ILOAD  CmdPtr      ; load current command
	OUT    I2C_DATA    ; to I2C_DATA register
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	LOAD   CmdPtr
	ADDI   1           ; Increment to next command
	STORE  CmdPtr
	LOAD   CmdCnt
	ADDI   -1
	STORE  CmdCnt
	JPOS   I2CCmdLoop
	RETURN
CmdPtr: DW 0
CmdCnt: DW 0

ReadX:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CRCmd     ; load command
	OUT    I2C_CMD     ; to I2C_CMD register
	LOAD   AccXAddr    ; 
	OUT    I2C_DATA    ; to I2C_DATA register
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	IN     I2C_data    ; put the data in AC
	CALL   SwapBytes   ; bytes returned in wrong order; swap them
	RETURN
	
; This subroutine swaps the bytes in AC
SwapBytes:
	STORE  SBT1
	SHIFT  8
	STORE  SBT2
	LOAD   SBT1
	SHIFT  -8
	AND    LoByte
	OR     SBT2
	RETURN
SBT1: DW 0
SBT2: DW 0

; Subroutine to block until I2C device is idle.
; Enters error loop if no response for ~0.1 seconds.
BlockI2C:
	LOAD   Zero
	STORE  Temp        ; Used to check for timeout
BI2CL:
	LOAD   Temp
	ADDI   1           ; this will result in ~0.1s timeout
	STORE  Temp
	JZERO  I2CError    ; Timeout occurred; error
	IN     I2C_RDY     ; Read busy signal
	JPOS   BI2CL       ; If not 0, try again
	RETURN             ; Else return
I2CError:
	LOAD   Zero
	ADDI   &H12C       ; "I2C"
	OUT    Hex0        ; display error message
	JUMP   I2CError

;*******************************************************************************
; Abs: 2's complement absolute value
; Returns abs(AC) in AC
; Neg: 2's complement negation
; Returns -AC in AC
;*******************************************************************************
Abs:
	JPOS   Abs_r
Neg:
	XOR    NegOne       ; Flip all bits
	ADDI   1            ; Add one (i.e. negate number)
Abs_r:
	RETURN

; I2C Constants
I2CWCmd:  DW &H203A    ; write two i2c bytes, addr 0x3A
I2CRCmd:  DW &H123A    ; write one byte, read two bytes, addr 0x3A
AccXAddr: DW &H32      ; X acceleration register address.
AccCfg: ; List of commands to send the ADXL345 at startup
	DW 4           ; Number of commands to send
	DW &H3101      ; Right-justified 10-bit data, +/-4 G
	DW &H3800      ; No FIFO
	DW &H2C08      ; 25 samples per second
	DW &H2D08      ; No sleep



; Variables
Temp:      DW 0
Pattern:   DW 0
Score:     DW 0

; Useful values
Zero:      DW 0
NegOne:    DW -1
One:
Bit0:      DW &B0000000001
Bit1:      DW &B0000000010
Bit2:      DW &B0000000100
Bit3:      DW &B0000001000
Bit4:      DW &B0000010000
Bit5:      DW &B0000100000
Bit6:      DW &B0001000000
Bit7:      DW &B0010000000
Bit8:      DW &B0100000000
Bit9:      DW &B1000000000
LoByte:    DW &H00FF
HiByte:    DW &HFF00


; IO address constants
Switches:  EQU &H000
LEDs:      EQU &H001
Timer:     EQU &H002
Hex0:      EQU &H004
Hex1:      EQU &H005
I2C_cmd:   EQU &H090
I2C_data:  EQU &H091
I2C_rdy:   EQU &H092
