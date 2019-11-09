-------------------------------------------------------------------------------
-- crcGenerator.vhd
--
-- Author(s):     Jorgen Peddersen
-- Created:       19 Jan 2001
-- Last Modified: 26 Jan 2001
-- 
-- Calculates the CRC check for incoming and outgoing bytes of the ethernet 
-- frame.  Uses CRC-32 to generate the check.  The frame must be passed into
-- the CRC generator with 4 bytes of h00 at the end for a valid CRC.
-- Assert newFrame before every frame.  Assert newByte for each byte in the
-- frame, with the byte at inByte.  Only positive edges of newByte are 
-- detected.  crcValid indicates when a new byte can be received.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity crcGenerator is
    port (
    	clk: in STD_LOGIC;			-- Input clock
        rstn: in STD_LOGIC;			-- Asynchronous active low reset
        newFrame: in STD_LOGIC;		-- Assert to restart calculations
        newByte: in STD_LOGIC;		-- Assert to indicate a crcValid input byte
        inByte: in STD_LOGIC_VECTOR (7 downto 0);		-- Input byte
        crcValid: out STD_LOGIC;	-- Indicates crcValid CRC.  Active HIGH
        crcValue: out STD_LOGIC_VECTOR (31 downto 0)	-- CRC output
    );
end crcGenerator;

architecture crcGenerator_arch of crcGenerator is

signal presState : STD_LOGIC;			-- current state
constant stIdle : STD_LOGIC := '0';
constant stCalc : STD_LOGIC := '1';

signal bitCnt : INTEGER range 0 to 7;	-- counts bit in stCalc
signal byteCnt : INTEGER range 0 to 4;	-- counts the four initial bytes
signal crcValueInt : STD_LOGIC_VECTOR (31 downto 0);	-- stores current crc
signal latchedByte : STD_LOGIC_VECTOR (7 downto 0);		-- latches input byte
signal reversedByte : STD_LOGIC_VECTOR (7 downto 0);	-- bit reversedinByte
signal lastNewByte : STD_LOGIC;			-- previous value of newByte

-- Generator polynomial is
--  32   26   23   22   16   12   11   10   8   7   5   4   2   
-- x  + x  + x  + x  + x  + x  + x  + x  + x + x + x + x + x + x + 1
constant GENERATOR : STD_LOGIC_VECTOR := X"04C11DB7";

begin
	process(crcValueInt)
	-- Output is the inverted bit reversal of the internal signal
	begin
		for i in 0 to 31 loop -- invert and bit reverse
			crcValue(i) <= NOT crcValueInt(31-i);
		end loop;
	end process;

	process (inByte)
	-- Bit reversed version of inByte
	begin
		for i in 0 to 7 loop -- bit reverse
			reversedByte(i) <= inByte(7 - i);
		end loop;
	end process;
	
	process (clk,rstn)
	-- FSM
	begin
		if rstn = '0' then	-- reset signals to strting values
			presState <= stIdle;
			bitCnt <= 0;
			byteCnt<= 0;
			crcValueInt <= (others => '0');
			lastNewByte <= '0';
		elsif clk'event and clk = '1' then  -- operate on positive edge
			lastNewByte <= newByte;		-- remember previous value
			case presState is
				when stIdle =>
					bitCnt <= 0;
					crcValid <= '1';
					if newFrame = '1' then	-- reset crcGenerator to starting values
						presState <= stIdle;
						byteCnt <= 0;
						crcValueInt <= (others => '0');
						crcValid <= '0';
					elsif newByte = '1' and lastNewByte = '0' then -- positive edge
						if byteCnt /= 4 then	-- shift in inverted byte
							presState <= stIdle;	
							crcValueInt <= crcValueInt(23 downto 0) & NOT reversedByte;
							byteCnt <= byteCnt + 1;
							crcValid <= '0';
						else	-- go to calculation state after fourth byte
							presState <= stCalc;
							latchedByte <= inByte;	-- latch inByte
							crcValid <= '0';
						end if;
					end if;
				when stCalc =>	-- shift in byte in little-endian and XOR if necessary
					crcValid <= '0';
					if newFrame = '1' then	-- reset crcGenerator to starting values
						presState <= stIdle;
						crcValueInt <= (others => '0');
						crcValid <= '0';
						bitCnt <= 0;
					else	-- shift in current bit, LSB first.
						if crcValueInt(31) = '1' then	-- XOR with generator if MSB is '1'
							crcValueInt <= (crcValueInt(30 downto 0) & latchedByte(bitCnt)) XOR GENERATOR;
						else
							crcValueInt <= (crcValueInt(30 downto 0) & latchedByte(bitCnt));
						end if;
						if bitCnt = 7 then	-- stop after all bits are shifted in
							presState <= stIdle;
							crcValid <= '1';
							bitCnt <= 0;
						else	-- move to next bit
							presState <= stCalc;
							crcValid <= '0';	
							bitCnt <= bitCnt + 1;
						end if;
					end if;
				when others =>
					presState <= stIdle;
					crcValid <= '0';
					bitCnt <= 0;
			end case;
		end if;
	end process;
end crcGenerator_arch;
