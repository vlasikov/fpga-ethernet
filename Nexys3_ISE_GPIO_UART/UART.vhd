----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:07:54 11/02/2011 
-- Design Name: 
-- Module Name:    UART - Behavioral 
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
USE IEEE.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity UART is
generic (UART_Speed : integer := 9600 ;   -- UART Speed
          System_CLK : integer := 100000000    -- System CLK in Hz
      );

port (
      CLK      : in std_logic;       -- system clk
      RST_N    : in std_logic;       -- system reset#
      DATA_IN  : in std_logic_vector(7 downto 0); -- Transmit data
      DATA_OUT : out std_logic_vector(7 downto 0); --Recieved data
      RX_VALID : out std_logic;    -- RX buffer data ready
      TX_VALID : in  std_logic;         -- Data for TX avaible
      RXD      : in  std_logic;           -- RX pin
      TXD      : out std_logic ;        -- TX pin
      TX_BUSY  : out std_logic;    -- TX pin
      RX_BUSY  : out std_logic;
		TEST		: out std_logic
);
end UART;
---------------------------------------------------
-- Architecture for UART
---------------------------------------------------
architecture Behavioral of UART is

signal TxBuf   : Std_Logic_Vector(7 downto 0); -- transmit buffer
signal RxBuf   : Std_Logic_Vector(7 downto 0); -- recieve buffer
signal prevRXD : Std_Logic;           -- RXD buffer register
signal RxReady : Std_Logic;
signal TXRead  : Std_Logic;
signal TXtest  : Std_Logic;
signal TxBitCnt : integer range 0 to 9;
signal TxReady : Std_Logic;
signal CntRX : integer range 0 to System_CLK/(UART_Speed);
signal CntTX : integer range 0 to System_CLK/(UART_Speed);
signal RxBitCnt: integer range 0 to 10;

begin

UART_Tx: process(CLK, RST_N)

begin
  if RST_N='0' then
    TXD <= '1';
    TxBitCnt <= 0;
    TxBuf <= (others => '0');
    CntTX <= 0;
    TxReady <= '1';
  elsif (rising_edge(CLK)) then
    if (TX_VALID = '1' and TxReady = '1') then
      TxBuf(7 downto 0) <= DATA_IN(7 downto 0);
      TxReady <= '0';
      TxBitCnt <= 0;
      CntTX  <= 0;
    end if;

    if (TxReady = '0') then
      if (CntTX = (System_CLK/(UART_Speed)) ) then
        CntTX <= 0;
        case TxBitCnt is
          when 0 =>            
				TXD  <=  '0';       -- start bit
            TxBitCnt <= TxBitCnt+1;
          when 1|2|3|4|5|6|7|8 =>
            TXD      <= TxBuf(0);
            TxBuf    <= '0' & TxBuf(7 downto 1);
            TxBitCnt <= TxBitCnt+1;
          when 9 =>
            TXD      <= '1';    -- stop bit
            TxBuf    <= (others => '0');
            TxBitCnt <= 0;
            TxReady  <= '1';       
        end case;
--		end if;
--		if CntTX=(System_CLK/(UART_Speed)) then
--        CntTX <= 0;
      else
        CntTX <= CntTX+1;
      end if;
    end if;
  end if;
end process UART_Tx;
TX_BUSY <= not (TxReady);

UART_Rx: process(CLK, RST_N)
begin
  if RST_N='0' then
    RxBitCnt <=0;
    RxBuf <= (others => '0');
    RxReady <= '1';
    prevRXD <= '1';
    CntRX <= 0;
  elsif (rising_edge(CLK)) then
    if (RxReady = '1') then
      prevRXD <= RXD;
      --if (RXD='0' and prevRXD='1') then  -- Start bit,
		if (RXD='0') then  -- Start bit,
        RxBitCnt <= 0;              	-- RX Bit counter
        RxReady <= '0'; 					-- Start receiving
        RxBuf <= (others => '0');
        CntRX <= 0;
		  RX_VALID <= '0';
		  TXtest <= '0';
      end if;
    else
      if CntRX=(System_CLK/(UART_Speed*2)) then
			TXtest <= not (TXtest);
        case RxBitCnt is
          when 0 =>
            if (RXD='1') then -- start bit failed
              --RxReady <= '1';
				  RxReady <= '0';
				  RX_VALID <= '0';
            end if;
          when 1|2|3|4|5|6|7|8 =>
            RxBuf <= RXD & RxBuf(7 downto 1);
            RxReady <= '0';
          when 9 =>
            RxReady <= '1';
				RX_VALID <= '1';
          when others => RxReady <= '0';
        end case;
        CntRX <= CntRX+1;
        RxBitCnt <= RxBitCnt+1;
		elsif (CntRX=(System_CLK/(UART_Speed))) then
			CntRX <= 0;
		else
			CntRX <= CntRX+1;
		end if;
    end if;
  end if;
end process UART_Rx;

DATA_OUT(7 downto 0) <=  RxBuf(7 downto 0) when RxReady='1'
          else (others => '0');
--RX_VALID <= RxReady;
RX_BUSY  <= not (RxReady);
TEST <= TXtest;

end Behavioral;

