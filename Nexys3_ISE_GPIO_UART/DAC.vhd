----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:23:16 04/24/2012 
-- Design Name: 
-- Module Name:    DAC - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity DAC is
generic (	DAC_Speed : integer  := 10000000;   -- ADC Speed
				SIN_freq	 : integer  := 200000;
				System_CLK : integer := 100000000    -- System CLK in Hz
      );

port (
      CLK      : in std_logic;       -- system clk
		CLK_DAC	: out std_logic;
      RST_N    : in std_logic;       -- system reset#
		enable	: in std_logic;
		LD			: out std_logic;
      DATA_IN  : in std_logic_vector(11 downto 0); -- Transmit data
      DATA_OUT1 : out std_logic; 			-- Transmit data
		DATA_OUT2 : out std_logic 			-- Transmit data
);
end DAC;

architecture Behavioral of DAC is

signal en			: std_logic;
signal CntRX 		: integer range 0 to System_CLK/(DAC_Speed);
signal CntSIN 		: integer range 0 to System_CLK/(SIN_freq);
signal SIN_value 	: integer range 0 to 19;
signal TxBitCnt 	: integer range 0 to 15;
signal DAC_Data_buf1	: std_logic_vector (11 downto 0) :=  (others => '0');
signal DAC_Data_buf2	: std_logic_vector (11 downto 0) :=  (others => '0');
--type DAC_ARRAY is array (integer range<>) of std_logic_vector(11 downto 0);
type INT_ARRAY is array (integer range<>) of integer;
signal   SIN_ARRAY		 : INT_ARRAY (0 to 19):=(
2047, 2680, 3250, 3703, 3994,
4094, 3994, 3703, 3250, 2680,
2047, 1414,  844,  391,  100,
   0,  100,  391,  844, 1414 
);
signal   COS_ARRAY		 : INT_ARRAY (0 to 19):=(
4094, 3994, 3703, 3250, 2680,
2047, 1414,  844,  391,  100,
   0,  100,  391,  844, 1414,
2047, 2680, 3250, 3703, 3994
);

begin
DAC_TX: process(CLK, RST_N)
begin
	if (RST_N='1') then
    --RxBuf <= (others => '0');
		CntRX <= 0;
	elsif (rising_edge(CLK)) then
		if (en = '1') then
			TxBitCnt <= 0;
		end if;
			if (CntRX=0) then
				CLK_DAC <= '1';
			else
				if (CntRX=(System_CLK/(DAC_Speed * 2 ) - 1) ) then
					case TxBitCnt is
						when 0|1|2|3|4|5|6|7|8|9|10|11 =>
							CLK_DAC <= '0';
							LD <= '1';
							DATA_OUT1 <= DAC_Data_buf1(11-TxBitCnt);
							DATA_OUT2 <= DAC_Data_buf2(11-TxBitCnt);
							TxBitCnt <= TxBitCnt+1;
						when 12 =>
							LD <= '0';
							--DAC_Data_buf <= DAC_Data_buf + 1;
							TxBitCnt <= TxBitCnt+1;
						when others=>
							--TxBitCnt <= 0;
					end case;
				end if;
			end if;
			
			if (CntRX=(System_CLK/(SIN_freq) - 1)) then
				CntRX <= 0;
			else
				CntRX <= CntRX+1;
			end if;
		--end if;
	end if;

end process DAC_TX;

DAC_SIN: process(CLK)
begin
	if (rising_edge(CLK)) then
		if (CntSIN=(System_CLK/(SIN_freq) - 1)) then
				CntSIN <= 0;
		else
				CntSIN <= CntSIN + 1;
		end if;
		
		if (CntSIN=0) then
				en <= '1';
				DAC_Data_buf1 (11 downto 0) <= conv_std_logic_vector ( SIN_ARRAY(SIN_value),12 );
				DAC_Data_buf2 (11 downto 0) <= conv_std_logic_vector ( COS_ARRAY(SIN_value),12 );
				if (SIN_value < 19) then
					SIN_value <= SIN_value + 1;
				else
					SIN_value <= 0;
				end if;
		else
				en <= '0';
		end if;		
	end if;
end process DAC_SIN;

end Behavioral;

