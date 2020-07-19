; Starting point for filtering program.
; Once you're done with it, this program should display the number
; of acquired data samples on the left hex display, and perform
; an averaging filter on the data before converting it to the 
; bubble level display.

ORG 0
	CALL   SetupI2C    ; Configure ADXL345
	LOADI  0
	STORE  ReadCount   ; Initialize counter for display
	
ReadLoop:
	CALL   WaitForData ; Subroutine to wait for new data
	; (The subroutine doesn't do anything yet. It just returns immediately.)
	
	; Increment the acquisition counter and display it	
	LOAD   ReadCount
	ADDI   1
	STORE  ReadCount
	OUT    Hex1

	CALL	ReadX       ; Get the X acceleration data
	CALL	Abs
	STORE	X_abs
	CALL 	ReadY
	CALL	Abs
	STORE	Y_abs
	CALL	ReadZ
	CALL	Abs
	STORE	Z_abs
	
	LOADI	0
	ADD		X_abs
	ADD		Y_abs
	ADD		Z_abs
	STORE	Mag
	
	
	CALL	Filter      ; Calculate moving average
	CALL	Hex0        ; Display data

	; Manipuate the data to create a display on the LEDs.
	CALL   BarGraph

	JUMP   ReadLoop    ; Repeat forever
	
X_abs: DW 0
Y_abs: DW 0
Z_abs: DW 0
Mag:   DW 0

; Used for peak detection
StartVec0 DW 0
StartVec1 DW 0
StartVec2 DW 0 
EndVec0  DW 0
EndVec1  DW 0
EndVec2  DW 0

DetectPeak:
	LOAD StartVec0
	SUB  StartVec1
	JPOS NoPeak

	LOAD StartVec1
	SUB  StartVec2
	JPOS NoPeak

	LOAD StartVec2
	SUB  EndVec0
	JNEG NoPeak

	LOAD EndVec0
	SUB  EndVec1
	JPOS NoPeak

	LOAD EndVec1
	SUB  EndVec2
	JPOS NoPeak

	Jump PeakDetected ; TODO handling peak detected

NoPeak: ; Shift everything down
	LOAD StartVec1
	STORE StartVec0
	
	LOAD StartVec2
	STORE StartVec1

	LOAD EndVec0
	STORE StartVec2

	LOAD EndVec1
	STORE EndVec0

	LOAD EndVec2
	STORE EndVec1

	RETURN

; WaitForData will poll the ADXL345 until it responds that there is fresh data.
; Once this returns, you can read the accelerometer data and know that you
; aren't reading the same data more than once.
WaitForData:
	LOAD I2CR1Cmd     ; 1 byte will be written
	OUT  I2C_CMD
	LOAD INT_SOURCE   ; address of the INT_SOURCE register
	OUT  I2C_DATA
	OUT  I2C_RDY      ; start communictaion
	CALL BlockI2C
	IN   I2C_DATA     ; Load data
	AND  Bit7         ; Mask for DATA_READY 
	JZERO WaitForData ; If DATA_READY inactive
	RETURN

Filter:
	STORE  Xtemp        ; Store the acceleration data first
	LOAD   X1           ; Shift queue down
	STORE  X0
	LOAD   X2
	STORE  X1
	LOAD   X3
	STORE  X2
	LOAD   Xtemp
	STORE  X3
	CALL   Average
	RETURN

Average:
    LOAD X0
	ADD  X1
	ADD  X2
	ADD  X3
	SHIFT -2
	RETURN
	
; BarGraph ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Nothing in here is really important to understand, but feel free to
; peruse if you like reverse-engineering assembly code.
;
; This subroutine takes a value (in AC when subroutine is called)
; and displays it as bar graph that grows from the left or right
; depending on the sign of the value.
BarGraph:
	; Incoming data is too big, so reduce it to only a few bits.
	; At current scale, 2 G will be on bit 9 , so 1 G will be on bit 8.
	; I want to display *up to* 1 G using 3 bits so the bar fits on the
	; LEDs, so I want bits 7, 6, and 5.  That means discarding bits 4-0,
	; which is done with a 5-bit shift.
	SHIFT  -5
	STORE  BarVal
	; Value of zero will be a blank display
	JZERO  DisplayBar

	JPOS   BarLeft
	
BarRight:
	LOADI  0
	STORE  CurrBar
BarRightLoop:
	; Grow the bar
	LOAD   CurrBar
	SHIFT  1
	ADDI   1
	STORE  CurrBar
	; Loop if needed (counting up since value is negative)
	LOAD   BarVal
	ADDI   1
	STORE  BarVal
	JNEG   BarRightLoop
	; Loop done; display the bar
	LOAD   CurrBar
	JUMP   DisplayBar
	
BarLeft:
	; This will result in a negative number, which
	; will let us make use of the arithmetic shift
	; to grow the bar.
	LOADI  &B10000000000
	STORE  CurrBar
BarLeftLoop:
	; Grow the bar
	LOAD   CurrBar
	SHIFT  -1
	STORE  CurrBar
	; Loop if needed
	LOAD   BarVal
	ADDI   -1
	STORE  BarVal
	JPOS   BarLeftLoop
	; Loop done; display the bar
	LOAD   CurrBar
	JUMP   DisplayBar
	
DisplayBar:
	; Display the result on the LEDs and return
	OUT    LEDs
	RETURN

BarVal:    DW 0             ; Incoming data value
CurrBar:   DW 0             ; Current LED display


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

CurrX: DW 0
CurrY: DW 0
CurrZ: DW 0

ReadX:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CR2Cmd    ; load command
	OUT    I2C_CMD     ; to I2C_CMD register
	LOAD   AccXAddr    ; 
	OUT    I2C_DATA    ; to I2C_DATA register
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	IN     I2C_data    ; put the data in AC
	CALL   SwapBytes   ; bytes returned in wrong order; swap them
	RETURN
	
ReadY:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CR2Cmd    ; load command
	OUT    I2C_CMD     ; to I2C_CMD register
	LOAD   AccYAddr    ; 
	OUT    I2C_DATA    ; to I2C_DATA register
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	IN     I2C_data    ; put the data in AC
	CALL   SwapBytes   ; bytes returned in wrong order; swap them
	RETURN
	
ReadZ:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CR2Cmd    ; load command
	OUT    I2C_CMD     ; to I2C_CMD register
	LOAD   AccZAddr    ; 
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
I2CR1Cmd: DW &H113A    ; write one byte, read one byte, addr 0x3A

I2CR2Cmd: DW &H123A    ; write one byte, read two bytes, addr 0x3A

INT_SOURCE: DW &H030
AccXAddr: DW &H32      ; X acceleration register address.
AccYAddr: DW &H34      ; Y
AccZAddr: DW &H36      ; Z
AccCfg: ; List of commands to send the ADXL345 at startup
	DW 5           ; Number of commands to send
	DW &H0000      ; Meaningless write to sync communication
	DW &H3100      ; Right-justified 10-bit data, +/-2 G
	DW &H3800      ; No FIFO
	DW &H2C06      ; 6.25 samples per second
	DW &H2D08      ; No sleep



; Variables
Temp:      DW 0
ReadCount: DW 0
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

; Filter variables
X0:         DW 0
X1:         DW 0
X2:         DW 0
X3:         DW 0
Xtemp:      DW 0


; IO address constants
Switches:  EQU &H000
LEDs:      EQU &H001
Timer:     EQU &H002
Hex0:      EQU &H004
Hex1:      EQU &H005
I2C_cmd:   EQU &H090
I2C_data:  EQU &H091
I2C_rdy:   EQU &H092
