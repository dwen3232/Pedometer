Loop:
	LOAD Counter
	OUT Hex1
	IN  KEY1
	JPOS AddOne
	JUMP LOOP

AddOne:
	LOAD Counter
	ADDI 1
	STORE Counter
	RETURN
	
Counter:  DW 5

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
