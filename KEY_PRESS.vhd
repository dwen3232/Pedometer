-- KEY_PRESS.VHD (a peripheral module for SCOMP)
-- 2020.7.20
--
-- This module is used to drive KEY1, copied
-- and modified from DIG_OUT.VHD


LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE LPM.LPM_COMPONENTS.ALL;


ENTITY KEY_PRESS IS
  PORT(
	 CS          : IN STD_LOGIC;
	 KEY         : IN STD_LOGIC;
    IO_DATA     : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
	 IO_WRITE    : IN STD_LOGIC
  );
END KEY_PRESS;


ARCHITECTURE a OF KEY_PRESS IS
  SIGNAL IO_OUT : STD_LOGIC;
  SIGNAL OUTPUT : STD_LOGIC_VECTOR(15 DOWNTO 0);
  
  BEGIN
  
  -- Use LPM function for tristate I/O data bus
  IO_BUS: lpm_bustri
  GENERIC MAP (
	lpm_width => 16
  )
  PORT MAP (
    data => OUTPUT,
	 enabledt => IO_OUT,
	 tridata => IO_DATA
  );
  
  IO_OUT <= (CS AND NOT(IO_WRITE));

 PROCESS (CS, KEY)
	BEGIN
	  IF (RISING_EDGE(CS)) THEN
		 OUTPUT <= "000000000000000" & KEY;
	  END IF;
	END PROCESS;
END a;
