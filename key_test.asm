Loop:
	CALL	KeyTest
	LOAD	KeyPressed
	JPOS	AddOne
	LOAD	Counter
	OUT		Hex0
	Jump	Loop

AddOne:
	LOAD Counter
	ADDI 1
	STORE Counter
	RETURN
	
KeyTest:
	LOADI	0
	STORE	KeyPressed
	LOAD	KeyDown
	AND		Bit0
	JPOS	WasDown
	
	
	IN		Key1
	AND		Bit0
	JZERO	NotPressed
	LOADI	1
	STORE	KeyDown
	JUMP	NotPressed
	
	WasDown:
		IN		Key1
		AND		Bit0
		JPOS	NotPressed
		LOADI	0
		STORE	KeyDown
		Jump	Pressed
	
	
	NotPressed:
			LOADI	0
			STORE	KeyPressed
			RETURN
			
	Pressed:
			LOADI	1
			STORE	KeyPressed
			RETURN
	

	
KeyDown:	DW 0
KeyPressed: DW 1
Bit0:      DW &B0000000001
Counter:	DW 0

; IO address constants
Switches:  EQU &H000
LEDs:      EQU &H001
Timer:     EQU &H002
Hex0:      EQU &H004
Hex1:      EQU &H005
Key1:      EQU &H006
I2C_cmd:   EQU &H090
I2C_data:  EQU &H091
I2C_rdy:   EQU &H092
