----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:51:12 01/25/2012 
-- Design Name: 
-- Module Name:    ETH - Behavioral 
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
--use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

use work.PCK_CRC32_D8.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ETH is
port (
      CLK      	: in std_logic;       -- system clk
		ETH_TXD		: inout  STD_LOGIC_VECTOR (3 downto 0);
		--ETH_TXD_4 	: out  STD_LOGIC;
		ETH_TX_CLK	: in  STD_LOGIC;
		ETH_TX_EN	: inout  STD_LOGIC := '0';
		
		ETH_RXD		: in  STD_LOGIC_VECTOR (3 downto 0);
		ETH_RX_CLK	: in  STD_LOGIC;
		ETH_RX_DV 	: in  STD_LOGIC;
		
		ETH_TX_DATA	: in  STD_LOGIC_VECTOR (15 downto 0);
		ETH_TX_DATA_write	: in std_logic;
		ETH_TX_DATA_ADDR	: in  STD_LOGIC_VECTOR (7 downto 0);
		ETH_TX_pack_trans : in std_logic
);
end ETH;

architecture Behavioral of ETH is

type 		CHAR_ARRAY is array (integer range<>) of std_logic_vector(7 downto 0);
signal   EHT_MAC_Destination	: CHAR_ARRAY (0 to 5):=(X"ff",X"ff",X"ff",X"ff",X"ff",X"ff");
constant EHT_IP_Destination  	: CHAR_ARRAY (0 to 3):=(X"c0",X"a8",X"01",X"48");					-- 192.168.1.72
constant EHT_Port_Destination	: CHAR_ARRAY (0 to 1):=(X"b1",X"8e");
constant EHT_MAC_Source 		: CHAR_ARRAY (0 to 5):=(X"00",X"1e",X"8c",X"3d",X"85",X"fa");
constant EHT_IP_Source  		: CHAR_ARRAY (0 to 3):=(X"C0",X"A8",X"01",X"fe");					-- 192.168.1.254
constant EHT_Port_Source 		: CHAR_ARRAY (0 to 1):=(X"8b",X"fd");

constant EHT_TX_PACK_ARP_LEN 	: natural := 60;
constant EHT_TX_PACK_UDP_LEN 	: natural := 100;--500
signal 	EHT_UDP_Len				: std_logic_vector (15 downto 0) := conv_std_logic_vector((EHT_TX_PACK_UDP_LEN - 34),16);  --X"001d";
signal 	EHT_UDP_Total_Length	: std_logic_vector (15 downto 0) := conv_std_logic_vector((EHT_TX_PACK_UDP_LEN - 14),16);
signal   EHT_TX_PACK_LEN 		: integer range 0 to 10000 := EHT_TX_PACK_ARP_LEN;
signal   EHT_TX_PACK	 			: CHAR_ARRAY (0 to (EHT_TX_PACK_UDP_LEN-1));
signal   EHT_TX_PACK_0 			: CHAR_ARRAY (0 to (EHT_TX_PACK_UDP_LEN-1));
signal   EHT_TX_PACK_number	: std_logic_vector (15 downto 0);
signal   EHT_TX_PACK_number1	: std_logic_vector (15 downto 0);
signal	ETH_TX_PACK_BUF		: CHAR_ARRAY (0 to (500-1));

constant EHT_RX_PACK_LEN 		: natural := 100;--256;
signal   EHT_RX_PACK			 	: CHAR_ARRAY (0 to (EHT_RX_PACK_LEN-1));

signal ETH_TX_state				: integer range 0 to 15 := 0;
signal ETH_TX_pack_cntr 		: integer range 0 to 2000 := 0;
signal ETH_TX_LSB					: std_logic := '0';
signal ETH_TX_err					: std_logic := '0';
signal ETH_TX_pack_trans_buf 	: std_logic := '0';
signal EHT_TX_byte				: std_logic_vector (7 downto 0);
signal ETH_TX_SYNCHRON_state	: integer range 0 to 15 := 0;
signal ETH_TX_SYNCHRON_a		: std_logic := '0';
signal ETH_TX_SYNCHRON_b		: std_logic := '0';
signal ETH_TX_DATA_ADDR_buf	: integer range 0 to 1000 := 0;
signal ETH_TX_DATA_buf			: STD_LOGIC_VECTOR (15 downto 0);

signal ETH_WRITE_state	: integer range 0 to 255 := 0;

signal ETH_RX_DV_buf		: std_logic ;
signal ETH_RX_CLK_buf		: std_logic ;
signal ETH_RXD_buf			: std_logic_vector (3 downto 0);
signal ETH_RX_DV_buf1	: std_logic ;
signal ETH_TX_CLK_buf	: std_logic ;
signal EHT_TX_buf			: std_logic_vector (3 downto 0);
signal ETH_RX_cntr		: integer range 0 to 100 := 0;
signal ETH_RX_LSB			: std_logic := '0';
signal ETH_RX_state		: integer range 0 to 15 := 0;
signal ETH_RXD_1			: std_logic_vector (3 downto 0);
signal ETH_RX_byte		: std_logic_vector (7 downto 0);
signal EHT_RX_PACK_ARP_reply		: std_logic := '0';
signal EHT_RX_PACK_ARP_request	: std_logic := '0';

signal ETH_CRC_state		: integer range 0 to 255;
signal ETH_CRC_value_1	: std_logic_vector (31 downto 0);
signal ETH_CRC_cntr		: integer range 0 to 2000;
signal ETH_CRC_value_xor: std_logic_vector (31 downto 0);
signal EHT_CRC_byte		: std_logic_vector (7 downto 0);

signal ETH_BUF_state		: integer range 0 to 255;
signal ETH_BUF_cntr		: integer range 0 to 2000 := 0;

signal HeaderChecksum	: std_logic_vector (31 downto 0);
signal HeaderChecksum_state 	: integer range 0 to 255 :=0 ;
signal HeaderChecksum_calc		: std_logic :='0' ;

signal ETH_TX_Cntr		: std_logic_vector (31 downto 0);

constant ETH_cntr_max 	: natural := 100000;
signal ETH_cntr			: integer range 0 to 50000000 := 0;

begin

ETH_TX_pack_trans_buf <= ETH_TX_SYNCHRON_b;
ETH_SYNCHRON	: process (CLK)
begin
	if (rising_edge(CLK)) then
		--if (ETH_cntr >= ETH_cntr_max - 1) then
		if (ETH_TX_pack_trans = '1') then
			ETH_TX_SYNCHRON_a <= '1';
			ETH_cntr <= 0;
		else
			if (ETH_TX_SYNCHRON_b = '1') then
				ETH_TX_SYNCHRON_a <= '0';
			end if;
			ETH_cntr <= ETH_cntr + 1;
		end if;
	end if;	
end process;

ETH_SYNCHRON1	: process (ETH_TX_CLK_buf)
begin
	if (rising_edge(ETH_TX_CLK_buf)) then
		case ETH_TX_SYNCHRON_state is 
		when 0 =>										
			if (ETH_TX_SYNCHRON_a = '1') then
				ETH_TX_SYNCHRON_b <= '1';
				ETH_TX_SYNCHRON_state <= ETH_TX_SYNCHRON_state + 1;
			end if;
		when 1 =>										
			ETH_TX_SYNCHRON_b <= '0';
			ETH_TX_SYNCHRON_state <= ETH_TX_SYNCHRON_state + 1;
		when others=>
			ETH_TX_SYNCHRON_state <= 0;
		end case;
	end if;
end process;

--ETH_SYNCHRON	: process (ETH_TX_CLK_buf)
--begin
--	if (rising_edge(ETH_TX_CLK_buf)) then
--		if (ETH_cntr >= ETH_cntr_max - 1) then
--			ETH_cntr <= 0;
--			ETH_TX_SYNCHRON_b <= '1';
--		else
--			ETH_cntr <= ETH_cntr + 1;
--			ETH_TX_SYNCHRON_b <= '0';
--		end if;
--	end if;
--end process;

ETH_RX_process : process (ETH_RX_CLK_buf)
begin
	if (rising_edge (ETH_RX_CLK_buf)) then	
		if ((ETH_RX_DV_buf = '1') and (ETH_RX_cntr < EHT_RX_PACK_LEN)) then
			if (ETH_RX_LSB = '0') then
				ETH_RXD_1(3 downto 0) <= ETH_RXD_buf(3 downto 0);
				ETH_RX_LSB <= '1';
			else
				if (ETH_RX_cntr > 7) then
					--EHT_RX_PACK(ETH_RX_cntr-8)(7 downto 0) <= ETH_RXD_1(3 downto 0) &  ETH_RXD_buf(3 downto 0);
					EHT_RX_PACK(ETH_RX_cntr-8)(7 downto 0) <= ETH_RXD_buf(3 downto 0) &  ETH_RXD_1(3 downto 0);
				end if;
				ETH_RX_LSB <= '0';
				ETH_RX_cntr <= ETH_RX_cntr + 1;
			end if;			
		else
			ETH_RX_LSB <= '0';
			ETH_RX_cntr <= 0;
			--ETH_RX_state <= ETH_RX_state + 1;
		end if;			
	end if;
end process;

ETH_READ_process : process (ETH_RX_CLK_buf)
begin
	if (rising_edge (ETH_RX_CLK_buf)) then
		ETH_RX_DV_buf1 <= ETH_RX_DV_buf;
		if(ETH_RX_DV_buf1 = '1' and ETH_RX_DV_buf = '0') then
			if ( 	EHT_RX_PACK(0)  = EHT_MAC_Source(0) and		-- main MAC
					EHT_RX_PACK(1)  = EHT_MAC_Source(1) and
					EHT_RX_PACK(2)  = EHT_MAC_Source(2) and
					EHT_RX_PACK(3)  = EHT_MAC_Source(3) and
					EHT_RX_PACK(4)  = EHT_MAC_Source(4) and
					EHT_RX_PACK(5)  = EHT_MAC_Source(5) and							
					EHT_RX_PACK(12) = X"08" and						-- ARP
					EHT_RX_PACK(13) = X"06" and
					EHT_RX_PACK(20) = X"00" and						-- ARP reply
					EHT_RX_PACK(21) = X"02"					
				) then
				EHT_RX_PACK_ARP_reply <= '1';
				EHT_MAC_Destination (0) <= EHT_RX_PACK(6);
				EHT_MAC_Destination (1) <= EHT_RX_PACK(7);
				EHT_MAC_Destination (2) <= EHT_RX_PACK(8);
				EHT_MAC_Destination (3) <= EHT_RX_PACK(9);
				EHT_MAC_Destination (4) <= EHT_RX_PACK(10);
				EHT_MAC_Destination (5) <= EHT_RX_PACK(11);
			end if;
			if ( 	EHT_RX_PACK(0)  = X"FF" and		-- main MAC
					EHT_RX_PACK(1)  = X"FF" and
					EHT_RX_PACK(2)  = X"FF" and
					EHT_RX_PACK(3)  = X"FF" and
					EHT_RX_PACK(4)  = X"FF" and
					EHT_RX_PACK(5)  = X"FF" and
					EHT_RX_PACK(6)  = EHT_MAC_Destination(0) and
					EHT_RX_PACK(7)  = EHT_MAC_Destination(1) and
					EHT_RX_PACK(8)  = EHT_MAC_Destination(2) and
					EHT_RX_PACK(9)  = EHT_MAC_Destination(3) and
					EHT_RX_PACK(10) = EHT_MAC_Destination(4) and
					EHT_RX_PACK(11) = EHT_MAC_Destination(5) and
					EHT_RX_PACK(12) = X"08" and						-- ARP
					EHT_RX_PACK(13) = X"06" and
					EHT_RX_PACK(20) = X"00" and						-- ARP request
					EHT_RX_PACK(21) = X"01"					
				) then
				EHT_RX_PACK_ARP_request <= '1';
			end if;
		end if;
	end if;
end process;

ETH_TX_process : process (ETH_TX_CLK_buf)
begin
	if (rising_edge(ETH_TX_CLK_buf)) then	
		case ETH_TX_state is 
		when 0 =>										
			if (ETH_TX_pack_trans_buf = '1') then
				EHT_TX_PACK_number <= EHT_TX_PACK_number + 1;
				ETH_TX_state <= ETH_TX_state + 1;
			end if;
		when 1 =>
			ETH_TX_pack_cntr <= 0;
			ETH_TX_EN <= '0';
			ETH_TX_LSB <= '0';
			ETH_TX_err <= '0';
			if (ETH_RX_DV_buf = '0') then														-- от коллизий
				ETH_TX_state <= ETH_TX_state + 1;
			end if;
		when 2 =>										-- 
			if (ETH_TX_pack_cntr < (EHT_TX_PACK_LEN + 8 + 4) ) then
				if (ETH_RX_DV_buf = '0') then
					ETH_TX_EN <= '1';
					if (ETH_TX_LSB = '0') then
						EHT_TX_buf(3 downto 0) <=  EHT_TX_byte(3 downto 0);
						ETH_TX_LSB <= '1';
					else
						EHT_TX_buf(3 downto 0) <=  EHT_TX_byte(7 downto 4);
						ETH_TX_LSB <= '0';
						ETH_TX_pack_cntr <= ETH_TX_pack_cntr + 1;
					end if;
				else
					--ETH_TX_err <= '1';
					ETH_TX_state <= ETH_TX_state + 1;
				end if;				
			else
				ETH_TX_EN <= '0';
				ETH_TX_LSB <= '0';
				ETH_TX_state <= ETH_TX_state + 1;
			end if;
		when others=>
			ETH_TX_state <= 0;
		end case;
		
	end if;
end process;

ETH_CRC_process : process (ETH_TX_CLK_buf)
begin
	if (rising_edge(ETH_TX_CLK_buf)) then		
--		if (ETH_TX_err = '1') then
--			EHT_TX_PACK_number1 <= X"0000";
--		end if;
	
		case ETH_CRC_state is 
		when 0 =>
			if (ETH_TX_pack_trans_buf = '1') then
				ETH_CRC_value_1 <= X"FFFFFFFF";
				ETH_CRC_cntr <= 0;
				if (EHT_TX_PACK_number1 < 29999) then
					EHT_TX_PACK_number1 <= EHT_TX_PACK_number1 + 1;
				else 
					EHT_TX_PACK_number1 <= X"0000";
				end if;
				
				ETH_CRC_state <= ETH_CRC_state + 1;
			end if;
		when 1 =>													-- задержка
			ETH_CRC_state <= ETH_CRC_state + 1;
		when 2 =>
			if (ETH_CRC_cntr < (EHT_TX_PACK_LEN)) then
				ETH_CRC_value_1 <= nextCRC32_D8(EHT_TX_PACK(ETH_CRC_cntr), ETH_CRC_value_1);
				ETH_CRC_cntr <= ETH_CRC_cntr + 1;
			else
				ETH_CRC_value_xor <= ETH_CRC_value_1 xor X"FFFFFFFF";
				ETH_CRC_state <= ETH_CRC_state + 1;
			end if;
		when 3 =>			
			ETH_CRC_state <= ETH_CRC_state + 1;
		when others=>
			ETH_CRC_state <= 0;
		end case;
		
	end if;
end process;

EHT_IPHeaderChecksum_process : process (ETH_TX_CLK_buf)
begin
	if (rising_edge(ETH_TX_CLK_buf)) then	
		case HeaderChecksum_state is
		when 0 =>
			if (ETH_TX_pack_trans_buf = '1') then
				HeaderChecksum_state <= HeaderChecksum_state +1;
			end if;
		when 1 =>
			HeaderChecksum(31 downto 0) <= 	X"00000000" +
														(EHT_TX_PACK(14)(7 downto 0) & EHT_TX_PACK(15)(7 downto 0))+
														(EHT_TX_PACK(16)(7 downto 0) & EHT_TX_PACK(17)(7 downto 0))+
														(EHT_TX_PACK(18)(7 downto 0) & EHT_TX_PACK(19)(7 downto 0))+
														(EHT_TX_PACK(20)(7 downto 0) & EHT_TX_PACK(21)(7 downto 0))+
														(EHT_TX_PACK(22)(7 downto 0) & EHT_TX_PACK(23)(7 downto 0))+
														--(EHT_TX_PACK_UDP(8+24)(7 downto 0) & EHT_TX_PACK_UDP(8+25)(7 downto 0))+
														(EHT_TX_PACK(26)(7 downto 0) & EHT_TX_PACK(27)(7 downto 0))+
														(EHT_TX_PACK(28)(7 downto 0) & EHT_TX_PACK(29)(7 downto 0))+
														(EHT_TX_PACK(30)(7 downto 0) & EHT_TX_PACK(31)(7 downto 0))+
														(EHT_TX_PACK(32)(7 downto 0) & EHT_TX_PACK(33)(7 downto 0));
			HeaderChecksum_state <= HeaderChecksum_state +1;
		when 2 =>
			HeaderChecksum <= X"00000000" + HeaderChecksum (31 downto 16) + HeaderChecksum (15 downto 0);
			HeaderChecksum_state <= HeaderChecksum_state +1;
		when 3 =>
			HeaderChecksum <= X"00000000" + HeaderChecksum (31 downto 16) + HeaderChecksum (15 downto 0);
			HeaderChecksum_state <= HeaderChecksum_state +1;
		when 4 =>
			HeaderChecksum <= X"0000FFFF" - HeaderChecksum;
			HeaderChecksum_state <= HeaderChecksum_state +1;
		when others=>
			HeaderChecksum_state <= 0;
		end case;
	end if;
end process;

--ETH_TX_WRITE_process : process (ETH_TX_CLK_buf)
--begin
--	if (rising_edge(ETH_TX_CLK_buf)) then
	
ETH_TX_WRITE_process : process (CLK)
begin
	if (rising_edge(CLK)) then
	
		case ETH_WRITE_state is 
		when 0 =>
			if (EHT_RX_PACK_ARP_reply = '1') then			-- получили арп ответ
				ETH_WRITE_state <= 1;
			end if;
		when 1 => 
			if (EHT_RX_PACK_ARP_request = '1') then
				ETH_WRITE_state <= 1;--2
			end if;
		when 2 =>
			if(EHT_RX_PACK_ARP_request = '0') then
				ETH_WRITE_state <= 1;
			end if;
		when others=>
			ETH_WRITE_state <= 0;
		end case;
		
				--ETH_WRITE_state <= ETH_WRITE_state + 1;
	
		EHT_TX_PACK(0)  <= EHT_MAC_Destination(0);
		EHT_TX_PACK(1)  <= EHT_MAC_Destination(1);
		EHT_TX_PACK(2)  <= EHT_MAC_Destination(2);
		EHT_TX_PACK(3)  <= EHT_MAC_Destination(3);
		EHT_TX_PACK(4)  <= EHT_MAC_Destination(4);
		EHT_TX_PACK(5)  <= EHT_MAC_Destination(5);
		EHT_TX_PACK(6)  <= EHT_MAC_Source(0);
		EHT_TX_PACK(7)  <= EHT_MAC_Source(1);
		EHT_TX_PACK(8)  <= EHT_MAC_Source(2);
		EHT_TX_PACK(9)  <= EHT_MAC_Source(3);
		EHT_TX_PACK(10) <= EHT_MAC_Source(4);
		EHT_TX_PACK(11) <= EHT_MAC_Source(5);
		
		case ETH_WRITE_state is 
		when 2 =>
		--if (ETH_WRITE_state = 2) then
			EHT_TX_PACK_LEN <= EHT_TX_PACK_ARP_LEN;
			
			EHT_TX_PACK(12) <= X"08";						-- ARP
			EHT_TX_PACK(13) <= X"06";
			EHT_TX_PACK(14) <= X"00";						-- Ethernet
			EHT_TX_PACK(15) <= X"01";

			EHT_TX_PACK(16) <= X"08";						-- IP
			EHT_TX_PACK(17) <= X"00";
			EHT_TX_PACK(18) <= X"06";						-- hardware size
			EHT_TX_PACK(19) <= X"04";						-- protocol size
			EHT_TX_PACK(20) <= X"00";						-- request
			EHT_TX_PACK(21) <= X"02";
			EHT_TX_PACK(22) <= EHT_MAC_Source(0);		
			EHT_TX_PACK(23) <= EHT_MAC_Source(1);
			EHT_TX_PACK(24) <= EHT_MAC_Source(2);
			EHT_TX_PACK(25) <= EHT_MAC_Source(3);
			EHT_TX_PACK(26) <= EHT_MAC_Source(4);
			EHT_TX_PACK(27) <= EHT_MAC_Source(5);
			EHT_TX_PACK(28) <= EHT_IP_Source(0);
			EHT_TX_PACK(29) <= EHT_IP_Source(1);
			EHT_TX_PACK(30) <= EHT_IP_Source(2);
			EHT_TX_PACK(31) <= EHT_IP_Source(3);

			EHT_TX_PACK(32) <= EHT_MAC_Destination(0);						-- Destination MAC
			EHT_TX_PACK(33) <= EHT_MAC_Destination(1);
			EHT_TX_PACK(34) <= EHT_MAC_Destination(2);
			EHT_TX_PACK(35) <= EHT_MAC_Destination(3);
			EHT_TX_PACK(36) <= EHT_MAC_Destination(4);
			EHT_TX_PACK(37) <= EHT_MAC_Destination(5);
			EHT_TX_PACK(38) <= EHT_IP_Destination(0);
			EHT_TX_PACK(39) <= EHT_IP_Destination(1);
			EHT_TX_PACK(40) <= EHT_IP_Destination(2);
			EHT_TX_PACK(41) <= EHT_IP_Destination(3);
			EHT_TX_PACK(42) <= X"00";
			EHT_TX_PACK(43) <= X"00";
			EHT_TX_PACK(44) <= X"00";
			EHT_TX_PACK(45) <= X"00";
			EHT_TX_PACK(46) <= X"00";
			EHT_TX_PACK(47) <= X"00";
			
			EHT_TX_PACK(48) <= X"00";
			EHT_TX_PACK(49) <= X"00";
			EHT_TX_PACK(50) <= X"00";
			EHT_TX_PACK(51) <= X"00";
			EHT_TX_PACK(52) <= X"00";
			EHT_TX_PACK(53) <= X"00";
			EHT_TX_PACK(54) <= X"00";
			EHT_TX_PACK(55) <= X"00";
			EHT_TX_PACK(56) <= X"00";
			EHT_TX_PACK(57) <= X"00";
			EHT_TX_PACK(58) <= X"00";
			EHT_TX_PACK(59) <= X"00";
		--end if;
		when 0 =>
		---if (ETH_WRITE_state = 0) then
			EHT_TX_PACK_LEN <= EHT_TX_PACK_ARP_LEN;
		
			EHT_TX_PACK(12) <= X"08";						-- ARP
			EHT_TX_PACK(13) <= X"06";
			EHT_TX_PACK(14) <= X"00";						-- Ethernet
			EHT_TX_PACK(15) <= X"01";

			EHT_TX_PACK(16) <= X"08";						-- IP
			EHT_TX_PACK(17) <= X"00";
			EHT_TX_PACK(18) <= X"06";						-- hardware size
			EHT_TX_PACK(19) <= X"04";						-- protocol size
			EHT_TX_PACK(20) <= X"00";						-- request
			EHT_TX_PACK(21) <= X"01";
			EHT_TX_PACK(22) <= EHT_MAC_Source(0);		
			EHT_TX_PACK(23) <= EHT_MAC_Source(1);
			EHT_TX_PACK(24) <= EHT_MAC_Source(2);
			EHT_TX_PACK(25) <= EHT_MAC_Source(3);
			EHT_TX_PACK(26) <= EHT_MAC_Source(4);
			EHT_TX_PACK(27) <= EHT_MAC_Source(5);
			EHT_TX_PACK(28) <= EHT_IP_Source(0);
			EHT_TX_PACK(29) <= EHT_IP_Source(1);
			EHT_TX_PACK(30) <= EHT_IP_Source(2);
			EHT_TX_PACK(31) <= EHT_IP_Source(3);

			EHT_TX_PACK(32) <= X"00";						-- Destination MAC
			EHT_TX_PACK(33) <= X"00";
			EHT_TX_PACK(34) <= X"00";
			EHT_TX_PACK(35) <= X"00";
			EHT_TX_PACK(36) <= X"00";
			EHT_TX_PACK(37) <= X"00";
			EHT_TX_PACK(38) <= EHT_IP_Destination(0);
			EHT_TX_PACK(39) <= EHT_IP_Destination(1);
			EHT_TX_PACK(40) <= EHT_IP_Destination(2);
			EHT_TX_PACK(41) <= EHT_IP_Destination(3);
--				EHT_TX_PACK(42) <=EHT_RX_PACK(6);
--				EHT_TX_PACK(43) <=EHT_RX_PACK(7);
--				EHT_TX_PACK(44) <=EHT_RX_PACK(8);
--				EHT_TX_PACK(45) <=EHT_RX_PACK(9);
		--end if;
		when 1 =>
		--if (ETH_WRITE_state = 1) then
			EHT_TX_PACK_LEN <= EHT_TX_PACK_UDP_LEN;
			
		
			EHT_TX_PACK(12) <= X"08";						-- IP
			EHT_TX_PACK(13) <= X"00";
			EHT_TX_PACK(14) <= X"45";
			EHT_TX_PACK(15) <= X"00";

			EHT_TX_PACK(16) <= EHT_UDP_Total_Length(15 downto 8);
			EHT_TX_PACK(17) <= EHT_UDP_Total_Length(7 downto 0);				-- Len
			EHT_TX_PACK(18) <= X"00";
			EHT_TX_PACK(19) <= X"00";
			EHT_TX_PACK(20) <= X"40";						-- offset
			EHT_TX_PACK(21) <= X"00";
			EHT_TX_PACK(22) <= X"40";
			EHT_TX_PACK(23) <= X"11";						-- UDP
			EHT_TX_PACK(24) <= HeaderChecksum (15 downto 8);
			EHT_TX_PACK(25) <= HeaderChecksum (7 downto 0);
			EHT_TX_PACK(26) <= EHT_IP_Source(0);
			EHT_TX_PACK(27) <= EHT_IP_Source(1);
			EHT_TX_PACK(28) <= EHT_IP_Source(2);
			EHT_TX_PACK(29) <= EHT_IP_Source(3);
			EHT_TX_PACK(30) <= EHT_IP_Destination(0);
			EHT_TX_PACK(31) <= EHT_IP_Destination(1);

			EHT_TX_PACK(32) <= EHT_IP_Destination(2);
			EHT_TX_PACK(33) <= EHT_IP_Destination(3);
			EHT_TX_PACK(34) <= EHT_Port_Source(0);
			EHT_TX_PACK(35) <= EHT_Port_Source(1);
			EHT_TX_PACK(36) <= EHT_Port_Destination(0);
			EHT_TX_PACK(37) <= EHT_Port_Destination(1);
			EHT_TX_PACK(38) <= EHT_UDP_Len(15 downto 8);
			EHT_TX_PACK(39) <= EHT_UDP_Len(7 downto 0);

			EHT_TX_PACK(40) <= X"00";						-- UDP checksum
			EHT_TX_PACK(41) <= X"00";
			
			EHT_TX_PACK(42) <= EHT_TX_PACK_number1 (7 downto 0);		
			EHT_TX_PACK(43) <= EHT_TX_PACK_number1 (15 downto 8);		
			
			if ( (ETH_TX_DATA_write = '1') ) then
			
					--ETH_TX_DATA_ADDR_buf <= ETH_TX_DATA_ADDR;
	--				ETH_TX_DATA_ADDR_buf <= ETH_TX_DATA_ADDR_buf + 1;
	--				if (ETH_BUF_cntr < (EHT_TX_PACK_LEN - 44)) then
	--					ETH_BUF_cntr <= ETH_BUF_cntr + 1;
	--					EHT_TX_PACK(ETH_BUF_cntr) <= ETH_TX_DATA_ADDR_buf (7 downto 0);
	--					--EHT_TX_PACK(45 + ETH_BUF_cntr) <= ETH_TX_DATA_ADDR_buf (7 downto 0);
	--				end if;
					--EHT_TX_PACK(45 + conv_integer(ETH_TX_DATA_ADDR_buf)) <= ETH_TX_DATA_ADDR_buf (7 downto 0);
					--EHT_TX_PACK(45 + conv_integer(ETH_TX_DATA_ADDR)) <= ETH_TX_DATA (15 downto 8);
					--ETH_TX_PACK_BUF(conv_integer(ETH_TX_DATA_ADDR_buf)) <= ETH_TX_DATA_ADDR_buf (7 downto 0);
				EHT_TX_PACK(44 + conv_integer(ETH_TX_DATA_ADDR)) <= ETH_TX_DATA (7 downto 0);
				EHT_TX_PACK(45 + conv_integer(ETH_TX_DATA_ADDR)) <= ETH_TX_DATA (15 downto 8);
			end if;		
		--end if;

		when others=>
		end case;

--		case ETH_BUF_state is 
--		when 0 =>
--			if (ETH_TX_pack_trans_buf = '1') then
--				ETH_BUF_cntr <= 0;
--				ETH_BUF_state <= ETH_BUF_state + 1;
--			end if;
--		when 1 =>
--			if (ETH_BUF_cntr < (EHT_TX_PACK_LEN)) then
--				EHT_TX_PACK_0(ETH_BUF_cntr) <= EHT_TX_PACK(ETH_BUF_cntr);
--				ETH_BUF_cntr <= ETH_BUF_cntr + 1;
--			else
--				ETH_BUF_state <= ETH_BUF_state + 1;
--			end if;	
--		when others=>
--			ETH_BUF_state <= 0;
--		end case;
	
	end if;
end process;

--ETH_TX_buf_process : process (CLK)
ETH_TX_buf_process : process (ETH_TX_CLK_buf)
begin
	if (falling_edge(ETH_TX_CLK_buf)) then
	--if (rising_edge(CLK)) then
		if (ETH_TX_pack_cntr < 7) then
			EHT_TX_byte <= X"55";
		end if;
		if (ETH_TX_pack_cntr = 7) then
			EHT_TX_byte <= X"D5";
		end if;
		if ( (ETH_TX_pack_cntr > 7) and (ETH_TX_pack_cntr < (EHT_TX_PACK_LEN+8)) ) then
			EHT_TX_byte <= EHT_TX_PACK(ETH_TX_pack_cntr-8);
		end if;
		if (ETH_TX_pack_cntr = (EHT_TX_PACK_LEN-1+8+1) ) then
			EHT_TX_byte <= ETH_CRC_value_xor (7 downto 0);
		end if;
		if (ETH_TX_pack_cntr = (EHT_TX_PACK_LEN-1+8+2) ) then
			EHT_TX_byte <= ETH_CRC_value_xor (15 downto 8);
		end if;
		if (ETH_TX_pack_cntr = (EHT_TX_PACK_LEN-1+8+3) ) then
			EHT_TX_byte <= ETH_CRC_value_xor (23 downto 16);
		end if;
		if (ETH_TX_pack_cntr = (EHT_TX_PACK_LEN-1+8+4) ) then
			EHT_TX_byte <= ETH_CRC_value_xor (31 downto 24);
		end if;
	end if;
end process;


ETH_RX_DV_buf 				<= ETH_RX_DV;
ETH_RX_CLK_buf 			<= ETH_RX_CLK;
ETH_RXD_buf(3 downto 0) <= ETH_RXD(3 downto 0);
ETH_TX_CLK_buf 			<= ETH_TX_CLK;
ETH_TXD(3 downto 0) 		<= EHT_TX_buf(3 downto 0);

--UDP
--X"55",X"55",X"55",X"55",X"55",X"55",X"55",X"D5",  --преамбула
----MAC											MAC												IP(0800)		Head
--X"00",X"1d",X"92",X"75",X"a0",X"cc",X"00",X"1e",	X"8c",X"3d",X"85",X"fa",X"08",X"00",X"45",X"00",
----Tot Len	N				offset		x		UDP		checksum		IP(source)					IP(dis)			
--X"00",X"31",X"00",X"00",X"40",X"00",X"40",X"11",	X"00",X"00",X"C0",X"A8",X"01",X"fe",X"c0",X"a8",
----				port(source)port(des)	len				checksum		data
--X"01",X"47",X"8b",X"fd",X"b1",X"8e",X"00",X"1d",	X"00",X"00",X"42",X"72",X"6f",X"61",X"64",X"63",
----																															CRC
--X"61",X"73",X"74",X"20",X"6d",X"65",X"73",X"73",	X"61",X"67",X"65",X"20",X"37",X"39",X"00",X"00",
----
--X"00",X"00",X"00"

--ARP
--X"55",X"55",X"55",X"55",X"55",X"55",X"55",X"D5",  --преамбула
----MAC(dst)									MAC(source)										ARP(0806)	ETH()0001
--X"ff",X"ff",X"ff",X"ff",X"ff",X"ff",X"00",X"00",	X"00",X"00",X"00",X"00",X"08",X"06",X"00",X"01",
----IP (0800)					request		MAC(source)								  		IP(source)
--X"08",X"00",X"06",X"04",X"00",X"01",X"00",X"00",	X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00", 
----MAC(target)								IP(dst)							Trailer
--X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",	X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
----																									CRC
--X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",	X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"

end Behavioral;

