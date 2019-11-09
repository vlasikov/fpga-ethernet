library ieee;
use ieee.std_logic_1164.all;

package global_constants is

	-- IP and MAC addresses of the board
	constant DEVICE_IP : STD_LOGIC_VECTOR (31 downto 0) := x"82664267";
	constant DEVICE_MAC: STD_LOGIC_VECTOR (47 downto 0) := x"00aa0062c609";

end package global_constants;
