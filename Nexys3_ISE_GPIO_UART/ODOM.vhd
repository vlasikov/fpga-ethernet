----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:34:37 08/23/2012 
-- Design Name: 
-- Module Name:    ODOM - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ODOM is
port (
      CLK      : in std_logic;       -- system clk
		ODOM_ON	: out std_logic;  
		ODOM_CNTR: inout STD_LOGIC_VECTOR (15 downto 0);--integer range 0 to 65535;
		ODOM_DIR	: in std_logic;  
		ODOM_CLK	: in std_logic
);
end ODOM;

architecture Behavioral of ODOM is
signal test				: std_logic := '0';
signal ODOM_CLK_buf	: std_logic ;
signal ODOM_DIR_buf	: std_logic ;
signal ODOM_CLK_buf2	: std_logic ;
signal ODOM_CLK_buf3	: std_logic ;
--signal ODOM_CNTR	: integer range 0 to 65535 := 0;
signal ODOM_SYNCHRON_state				: integer range 0 to 15 := 0;

begin

ODOM_CLK_buf <= ODOM_CLK;
ODOM_DIR_buf <= ODOM_DIR;

ODOM_proc: process(CLK)
begin
	if (rising_edge(CLK)) then
		ODOM_CLK_buf2 <= ODOM_CLK_buf;
		ODOM_CLK_buf3 <= ODOM_CLK_buf2;
		
		case ODOM_SYNCHRON_state is 
		when 0 =>
			if ( (ODOM_CLK_buf3 = '0') and (ODOM_CLK_buf2 = '1') ) then
				ODOM_ON <= '1';
				if (ODOM_DIR_buf = '1') then
					ODOM_CNTR <= ODOM_CNTR + 1;
				else
					ODOM_CNTR <= ODOM_CNTR - 1;
				end if;
				ODOM_SYNCHRON_state <= ODOM_SYNCHRON_state + 1;					
			end if;
		When 1 => 
			ODOM_ON <= '0';
			ODOM_SYNCHRON_state <= ODOM_SYNCHRON_state + 1;	
		when others=>
			ODOM_SYNCHRON_state <= 0;
		end case;
	end if;
end process ODOM_proc;


end Behavioral;

