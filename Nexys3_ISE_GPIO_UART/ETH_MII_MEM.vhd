----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:52:20 11/18/2011 
-- Design Name: 
-- Module Name:    ETH_MII_MEM - Behavioral 
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
-- https://static.chipdip.ru/lib/010/DOC004010758.pdf

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

entity ETH_MII_MEM is
    Port ( clk     : in  STD_LOGIC;
           en     : in  STD_LOGIC;
           addr : in  STD_LOGIC_VECTOR (6 downto 0);
           do     : out  STD_LOGIC
        );
end ETH_MII_MEM;

architecture Behavioral of ETH_MII_MEM is
  type rom_type is array (0 to 127) of std_logic;
  signal rom : rom_type :=
  (
    --preambl
    '1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1',
    --ST
    '0','1',
    --OP CODE
    '0','1',
    --PHY ADDR
    '0','0','0','0','0',	-- default
    --REG ADDR
    '0','0','0','0','0',
    --TAR
    '1','0',			-- or 0 0
    --DATA
    '1','0','1','0','0','0','0','0',
    --DATA
    '0','0','0','0','0','0','0','0',
    --post
    --'1','1','1','1',
    --preambl
    '1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1',
    --ST
    '0','1',
    --OP CODE
    '0','1',
    --PHY ADDR
    '0','0','0','0','0',
    --REG ADDR
    '0','0','0','0','0',
    --TAR
    '1','0',
    --DATA
    '1','0','1','0','0','0','0','0',
    --DATA
    '0','0','0','0','0','0','0','0'
    --post
    --'1','1','1','1'    
    );
    
attribute rom_style: string;
attribute rom_style of rom: signal is "distributed";

begin
  process(clk)
  begin
    if clk'event and clk = '1' then
      if en = '1' then
        do <= rom(conv_integer(addr));
      end if;
    end if;
  end process;

end Behavioral;

