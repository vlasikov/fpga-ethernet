--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

package PCK_CONST is

-- type <new_type> is
--  record
--    <type_name>        : std_logic_vector( 7 downto 0);
--    <type_name>        : std_logic;
-- end record;
	type 		CHAR_ARRAY is array (integer range<>) of std_logic_vector(7 downto 0);
--
-- Declare constants
--
-- constant <constant_name>		: time := <time_unit> ns;
-- constant <constant_name>		: integer := <value;

	constant EHT_MAC_FF 				: CHAR_ARRAY (0 to 5):=(X"ff",X"ff",X"ff",X"ff",X"ff",X"ff");
	constant EHT_IP_Destination  	: CHAR_ARRAY (0 to 3):=(X"c0",X"a8",X"01",X"48");					-- 192.168.1.72
	constant EHT_Port_Destination	: CHAR_ARRAY (0 to 1):=(X"b1",X"8e");									-- 45454
	constant EHT_MAC_Source 		: CHAR_ARRAY (0 to 5):=(X"00",X"1e",X"8c",X"3d",X"85",X"fa");
	constant EHT_IP_Source  		: CHAR_ARRAY (0 to 3):=(X"C0",X"A8",X"01",X"fe");					-- 192.168.1.254
	constant EHT_Port_Source 		: CHAR_ARRAY (0 to 1):=(X"8b",X"fd");									-- 35837

	constant EHT_TX_PACK_ARP_LEN 	: natural := 60; --42 60
	constant EHT_TX_PACK_UDP_LEN 	: natural := 100;--500
	
--
-- Declare functions and procedure
--
-- function <function_name>  (signal <signal_name> : in <type_declaration>) return <type_declaration>;
-- procedure <procedure_name> (<type_declaration> <constant_name>	: in <type_declaration>);
--

end PCK_CONST;

package body PCK_CONST is

---- Example 1
--  function <function_name>  (signal <signal_name> : in <type_declaration>  ) return <type_declaration> is
--    variable <variable_name>     : <type_declaration>;
--  begin
--    <variable_name> := <signal_name> xor <signal_name>;
--    return <variable_name>; 
--  end <function_name>;

---- Example 2
--  function <function_name>  (signal <signal_name> : in <type_declaration>;
--                         signal <signal_name>   : in <type_declaration>  ) return <type_declaration> is
--  begin
--    if (<signal_name> = '1') then
--      return <signal_name>;
--    else
--      return 'Z';
--    end if;
--  end <function_name>;

---- Procedure Example
--  procedure <procedure_name>  (<type_declaration> <constant_name>  : in <type_declaration>) is
--    
--  begin
--    
--  end <procedure_name>;
 
end PCK_CONST;
