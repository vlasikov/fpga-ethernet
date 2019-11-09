----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:47:27 11/10/2011 
-- Design Name: 
-- Module Name:    ADC - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ADC is
generic (	ADC_Speed : integer  := 4000000;   -- ADC Speed
				System_CLK : integer := 100000000    -- System CLK in Hz
      );
port (
      CLK      : in std_logic;       -- system clk
		CLK_ADC	: out std_logic;
      RST_N    : in std_logic;       -- system reset#
		enable	: in std_logic;
      DATA_IN  : in std_logic_vector(11 downto 0); -- Transmit data
      DATA_OUT : out std_logic_vector(11 downto 0); --Recieved data
      RX_VALID : out std_logic    -- RX buffer data ready
);
end ADC;

architecture Behavioral of ADC is

signal RxBuf   : Std_Logic_Vector(11 downto 0); -- recieve buffer
signal CntRX 	: integer range 0 to System_CLK/(ADC_Speed);
signal RxReady : Std_Logic;
signal CLK_ADC_buf : Std_Logic;

begin

ADC_Rx: process(CLK, RST_N)
begin
  if RST_N='1' then
	 RxBuf <= (others => '0');
	 CntRX <= 0;
  elsif (rising_edge(CLK)) then
    if (enable = '1') then
      if (CntRX=0) then
			CLK_ADC_buf <= '1';
			RxBuf(11 downto 0) <= DATA_IN(11 downto 0);
			RxReady <='1';
		else
			RxReady <='0';
			if (CntRX=(System_CLK/(ADC_Speed * 2 ) - 1) ) then
				CLK_ADC_buf <= '0';
			end if;
		end if;
		
		if (CntRX=(System_CLK/(ADC_Speed) - 1)) then
				CntRX <= 0;
		else
			CntRX <= CntRX+1;
		end if;
		
    end if;
  end if;
end process ADC_Rx;

RX_VALID <= RxReady;
CLK_ADC <= CLK_ADC_buf;
DATA_OUT(11 downto 0) <=  RxBuf(11 downto 0);-- when RxReady='1'
          --else (others => '0');

end Behavioral;

