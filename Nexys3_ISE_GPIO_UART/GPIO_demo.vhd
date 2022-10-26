----------------------------------------------------------------------------
--	GPIO_demo.vhd -- Nexys3 GPIO/UART Demonstration Project
----------------------------------------------------------------------------
-- Author:  Sam Bobrowicz
--          Copyright 2011 Digilent, Inc.
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
--	The GPIO/UART Demo project demonstrates a simple usage of the Nexys3's 
-- GPIO and UART in an ISE design. The behavior is as follows:
--
--	      *The 8 User LEDs are tied to the 8 User Switches. While the center
--			 User button is pressed, the LEDs are instead tied to GND
--	      *The 7-Segment display counts from 0 to 9 on each of it 4
--        digits. This count is reset when the center button is pressed.
--        Also, single anodes of the 7-Segment display are blanked by
--	       holding BTNU, BTNL, BTND, or BTNR. Holding the center button 
--        blanks all the 7-Segment anodes.
--       *An introduction message is sent across the UART when the device
--        is finished being configured, and after the center User button
--        is pressed.
--       *A message is sent over UART whenever BTNU, BTNL, BTND, or BTNR is
--        pressed.
--       *Note that the center user button behaves as a user reset button
--        and is referred to as such in the code comments below
--        
--	All UART communication can be captured by attaching the UART port to a
-- computer running a Terminal program with 9600 Baud Rate, 8 data bits, no 
-- parity, and 1 stop bit.																
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Revision History:
--  08/08/2011(SamB): Created using Xilinx Tools 13.2
----------------------------------------------------------------------------
Library UNISIM;
use UNISIM.vcomponents.all;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--The IEEE.std_logic_unsigned contains definitions that allow 
--std_logic_vector types to be used with the + operator to instantiate a 
--counter.
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

use work.PCK_CRC32_D8.all;


entity GPIO_demo is
    Port ( SW 			: in  STD_LOGIC_VECTOR (7 downto 0);
           BTN 		: in  STD_LOGIC_VECTOR (4 downto 0);
           CLK 		: in  STD_LOGIC;
           LED 		: out  STD_LOGIC_VECTOR (7 downto 0);
           SSEG_CA 	: out  STD_LOGIC_VECTOR (7 downto 0);
			  SSEG_AN 	: out  STD_LOGIC_VECTOR (3 downto 0);
           UART_RXD 	: in  STD_LOGIC;
			  UART_TXD 	: out  STD_LOGIC;
			  
			  MUX			: inout  STD_LOGIC_VECTOR (4 downto 0);
			  
			  ADC_CLK 	: out  STD_LOGIC;
			  ADC_IN 	: in  STD_LOGIC_VECTOR (11 downto 0);
			  
			  DAC_CLK 	: out  STD_LOGIC;
			  DAC_SDI1	: out  STD_LOGIC;
			  DAC_SDI2	: out  STD_LOGIC;
			  DAC_LD		: out  STD_LOGIC;
			  
			  ODOM_CLK	: in  std_logic;
			  ODOM_DIR	: in  std_logic;
			  
			  SENSOR_VMT: in  std_logic;
			  
			  ETH_TXD	: out  STD_LOGIC_VECTOR (3 downto 0) := "0000";		--out
			  ETH_TXD_4 : out  STD_LOGIC := '0';									--out
			  ETH_TX_CLK: in  STD_LOGIC;
			  ETH_TX_EN	: inout  STD_LOGIC := '0';
			  ETH_RXD	: inout  STD_LOGIC_VECTOR (3 downto 0) := "0010";	--PHYAD2, RMIISEL, MODE1, MODE0
			  ETH_RX_CLK: in  STD_LOGIC;
			  ETH_RX_DV : in  STD_LOGIC;
			  ETH_MDIO	: inout  STD_LOGIC;
			  ETH_MDC	: out  STD_LOGIC;			  
			  ETH_COL	: out  STD_LOGIC := '1';									-- MODE2
			  
			  ETH_RST	: inout  STD_LOGIC := '0'
			  );
end GPIO_demo;

architecture Behavioral of GPIO_demo is

component UART_TX_CTRL
Port(
	SEND : in std_logic;
	DATA : in std_logic_vector(7 downto 0);
	CLK : in std_logic;          
	READY : out std_logic;
	UART_TX : out std_logic
	);
end component;


component ETH_MII_MEM
Port ( clk     : in  STD_LOGIC;
       en     	: in  STD_LOGIC;
       addr 	: in  STD_LOGIC_VECTOR (6 downto 0);
       do     	: out  STD_LOGIC
);
end component;

component ETH
Port ( 	CLK      	: in std_logic;       -- system clk
			ETH_TXD		: out  STD_LOGIC_VECTOR (3 downto 0);
			--ETH_TXD_4 	: out  STD_LOGIC;
			ETH_TX_CLK	: in  STD_LOGIC;
			ETH_TX_EN	: out  STD_LOGIC := '0';
			
			ETH_RXD		: in  STD_LOGIC_VECTOR (3 downto 0);
			ETH_RX_CLK	: in  STD_LOGIC;
			ETH_RX_DV 	: in  STD_LOGIC;
		
			ETH_TX_DATA	: in  STD_LOGIC_VECTOR (15 downto 0);
			ETH_TX_DATA_write	: in std_logic;
			ETH_TX_DATA_ADDR	: in  STD_LOGIC_VECTOR (7 downto 0);
			ETH_TX_pack_trans : in std_logic
);
end component;

component ADC
port (
      CLK      : in std_logic;       -- system clk
		CLK_ADC	: out std_logic;
      RST_N    : in std_logic;       -- system reset#
		enable	: in std_logic;
      DATA_IN  : in std_logic_vector(11 downto 0); -- Transmit data
      DATA_OUT : out std_logic_vector(11 downto 0); --Recieved data
      RX_VALID : out std_logic    -- RX buffer data ready
);
end component;

component DAC
port (
      CLK      : in std_logic;       -- system clk
		CLK_DAC	: out std_logic;
      RST_N    : in std_logic;       -- system reset#
		enable	: in std_logic;
		LD			: out std_logic;
      DATA_IN  : in std_logic_vector(11 downto 0); -- Recieved data
      DATA_OUT1 : out std_logic; 			-- Transmit data
		DATA_OUT2 : out std_logic 			-- Transmit data
);
end component;

component ODOM
port (
      CLK      : in std_logic;       -- system clk
		ODOM_ON	: out std_logic;  
		ODOM_CNTR: inout STD_LOGIC_VECTOR (15 downto 0);
		ODOM_DIR	: in std_logic; 
		ODOM_CLK	: in std_logic
);
end component;

component UART
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
end component;

component btn_debounce
Port(
		BTN_I : in std_logic_vector(4 downto 0);
		CLK : in std_logic;          
		BTN_O : out std_logic_vector(4 downto 0)
		);
end component;

--component qwe
--Port(		);
--end component;

--The type definition for the UART state machine type. Here is a description of what
--occurs during each state:
-- RST_REG     -- Do Nothing. This state is entered after configuration or a user reset.
--                The state is set to LD_INIT_STR.
-- LD_INIT_STR -- The Welcome String is loaded into the sendStr variable and the strIndex
--                variable is set to zero. The welcome string length is stored in the StrEnd
--                variable. The state is set to SEND_CHAR.
-- SEND_CHAR   -- uartSend is set high for a single clock cycle, signaling the character
--                data at sendStr(strIndex) to be registered by the UART_TX_CTRL at the next
--                cycle. Also, strIndex is incremented (behaves as if it were post 
--                incremented after reading the sendStr data). The state is set to RDY_LOW.
-- RDY_LOW     -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go low, 
--                indicating a send operation has begun. State is set to WAIT_RDY.
-- WAIT_RDY    -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go high, 
--                indicating a send operation has finished. If READY is high and strEnd = 
--                StrIndex then state is set to WAIT_BTN, else if READY is high and strEnd /=
--                StrIndex then state is set to SEND_CHAR.
-- WAIT_BTN    -- Do nothing. Wait for a button press on BTNU, BTNL, BTND, or BTNR. If a 
--                button press is detected, set the state to LD_BTN_STR.
-- LD_BTN_STR  -- The Button String is loaded into the sendStr variable and the strIndex
--                variable is set to zero. The button string length is stored in the StrEnd
--                variable. The state is set to SEND_CHAR.
type UART_STATE_TYPE is (RST_REG, LD_INIT_STR, SEND_CHAR, RDY_LOW, WAIT_RDY, WAIT_BTN, LD_BTN_STR);

--The CHAR_ARRAY type is a variable length array of 8 bit std_logic_vectors. 
--Each std_logic_vector contains an ASCII value and represents a character in
--a string. The character at index 0 is meant to represent the first
--character of the string, the character at index 1 is meant to represent the
--second character of the string, and so on.
type CHAR_ARRAY is array (integer range<>) of std_logic_vector(7 downto 0);
type CHAR_ARRAY_1 is array (integer range<>) of std_logic_vector(0 to 7);
type INT_ARRAY is array (integer range<>) of integer;

--constant TMR_CNTR_MAX : std_logic_vector(26 downto 0) := "101111101011110000100000000"; --"100,000,000 = clk cycles per second
constant TMR_CNTR_MAX : integer := 10000000; --100ms; --"25 ms Power, 100us reset
constant TMR_VAL_MAX : std_logic_vector(3 downto 0) := "1001"; --9

constant MAX_STR_LEN : integer := 27;
constant WELCOME_STR_LEN : natural := 27;
constant BTN_STR_LEN : natural := 24;

constant EHT_PACK_LEN : natural := 72;
signal   EHT_PACK		 : CHAR_ARRAY (0 to (EHT_PACK_LEN-1)):=(
X"55",X"55",X"55",X"55",X"55",X"55",X"55",X"D5",  --преамбула
--MAC											MAC												ARP(0806)	ETH()0001
X"ff",X"ff",X"ff",X"ff",X"ff",X"ff",X"02",X"05",	X"01",X"09",X"08",X"06",X"08",X"06",X"00",X"01",
--IP (0800)					request		MAC(sender)								  		IP(sender)
X"08",X"00",X"06",X"04",X"00",X"01",X"02",X"05",	X"01",X"09",X"08",X"06",X"C0",X"A8",X"01",X"02", 
--MAC(target)								IP(target)						Trailer
X"00",X"00",X"00",X"00",X"00",X"00",X"C0",X"A8",	X"01",X"47",X"00",X"00",X"00",X"00",X"00",X"00",
--																									CRC
X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",	X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"
); 

constant EHT_MAC_Destination	: CHAR_ARRAY (0 to 5):=(X"08",X"60",X"6E",X"68",X"3D",X"FE");
constant EHT_IP_Destination  	: CHAR_ARRAY (0 to 3):=(X"c0",X"a8",X"01",X"8a"); -- 192 168 1 138, 36529 (45454, 0xb18e)

constant EHT_MAC_Source 		: CHAR_ARRAY (0 to 5):=(X"00",X"1e",X"8c",X"3d",X"85",X"fa");
constant EHT_IP_Source  		: CHAR_ARRAY (0 to 3):=(X"C0",X"A8",X"01",X"fe"); -- 192 169 1 254

constant EHT_TX_PACK_UDP_LEN : natural := 75;
signal   EHT_TX_PACK_UDP		 : CHAR_ARRAY (0 to (EHT_TX_PACK_UDP_LEN-1)):=(
X"55",X"55",X"55",X"55",X"55",X"55",X"55",X"D5",  --преамбула
--MAC											MAC												IP(0800)		Head
X"08",X"60",X"6E",X"68",X"3D",X"FE",X"00",X"1e",	X"8c",X"3d",X"85",X"fa",X"08",X"00",X"45",X"00",
--Tot Len	N				offset		x		UDP		checksum		IP(source)					IP(dis)			
X"00",X"31",X"00",X"00",X"40",X"00",X"40",X"11",	X"b6",X"26",X"C0",X"A8",X"01",X"fe",X"c0",X"a8", 
--				port(source)port(des)	len				checksum		data
X"01",X"8a",X"8b",X"fd",X"b1",X"8e",X"00",X"1d",	X"00",X"00",X"42",X"72",X"6f",X"61",X"64",X"63",
--																															CRC
X"61",X"73",X"74",X"20",X"6d",X"65",X"73",X"73",	X"61",X"67",X"65",X"20",X"37",X"39",X"00",X"00",
--
X"00",X"00",X"00"
); --X"04",X"fc"  		X"78",X"ce"

--constant INT_ARRAY_LEN : natural := 100;
--signal   ADC_PACK_SIN		 : INT_ARRAY (0 to (INT_ARRAY_LEN-1)):=(
--0,		  062790, 125333, 187381, 248690, 309017, 368125, 425779, 481754, 535827, 
--587785, 637424, 684547, 728969, 770513, 809017, 844328, 876307, 904827, 929776, 
--951057, 968583, 982287, 992115, 998027, 
--1000000,998027, 992115, 982287, 968583, 951057, 929776, 904827, 876307, 844328, 
--809017, 770513, 728969, 684547, 637424, 587785, 535827, 481754, 425779, 368125, 
--309017, 248690, 187381, 125333, 062790,
--0,		   -062790, -125333, -187381, -248690, -309017, -368125, -425779, -481754, -535827, 
---587785, -637424, -684547, -728969, -770513, -809017, -844328, -876307, -904827, -929776, 
---951057, -968583, -982287, -992115, -998027,
---1000000,-998027, -992115, -982287, -968583, -951057, -929776, -904827, -876307, -844328, 
---809017, -770513, -728969, -684547, -637424, -587785, -535827, -481754, -425779, -368125, 
---309017, -248690, -187381, -125333, -062790
--);
--
--signal   ADC_PACK_COS		 : INT_ARRAY (0 to (INT_ARRAY_LEN-1)):=(
--1000000,998027, 992115, 982287, 968583, 951057, 929776, 904827, 876307, 844328, 
--809017, 770513, 728969, 684547, 637424, 587785, 535827, 481754, 425779, 368125, 
--309017, 248690, 187381, 125333, 062790,
--0,		   -062790, -125333, -187381, -248690, -309017, -368125, -425779, -481754, -535827, 
---587785, -637424, -684547, -728969, -770513, -809017, -844328, -876307, -904827, -929776, 
---951057, -968583, -982287, -992115, -998027,
---1000000,-998027, -992115, -982287, -968583, -951057, -929776, -904827, -876307, -844328, 
---809017, -770513, -728969, -684547, -637424, -587785, -535827, -481754, -425779, -368125, 
---309017, -248690, -187381, -125333, -062790,
--0,		  062790, 125333, 187381, 248690, 309017, 368125, 425779, 481754, 535827, 
--587785, 637424, 684547, 728969, 770513, 809017, 844328, 876307, 904827, 929776, 
--951057, 968583, 982287, 992115, 998027
--);

--Welcome string definition. Note that the values stored at each index
--are the ASCII values of the indicated character.
constant WELCOME_STR : CHAR_ARRAY(0 to 26) := (X"0A",  --\n
															  X"0D",  --\r
															  X"4E",  --N
															  X"45",  --E
															  X"58",  --X
															  X"59",  --Y
															  X"53",  --S
															  X"33",  --3
															  X"20",  -- 
															  X"47",  --G
															  X"50",  --P
															  X"49",  --I
															  X"4F",  --O
															  X"2F",  --/
															  X"55",  --U
															  X"41",  --A
															  X"52",  --R
															  X"54",  --T
															  X"20",  -- 
															  X"44",  --D
															  X"45",  --E
															  X"4D",  --M
															  X"4F",  --O
															  X"21",  --!
															  X"0A",  --\n
															  X"0A",  --\n
															  X"0D"); --\r
															  
--Button press string definition.
constant BTN_STR : CHAR_ARRAY(0 to 23) :=     (X"42",  --B
															  X"75",  --u
															  X"74",  --t
															  X"74",  --t
															  X"6F",  --o
															  X"6E",  --n
															  X"20",  -- 
															  X"70",  --p
															  X"72",  --r
															  X"65",  --e
															  X"73",  --s
															  X"73",  --s
															  X"20",  --
															  X"64",  --d
															  X"65",  --e
															  X"74",  --t
															  X"65",  --e
															  X"63",  --c
															  X"74",  --t
															  X"65",  --e
															  X"64",  --d
															  X"21",  --!
															  X"0A",  --\n
															  X"0D"); --\r

--This is used to determine when the 7-segment display should be
--incremented
signal tmrCntr : std_logic_vector(26 downto 0) := (others => '0');

--This counter keeps track of which number is currently being displayed
--on the 7-segment.
signal tmrVal : std_logic_vector(3 downto 0) := (others => '0');

--Contains the current string being sent over uart.
signal sendStr : CHAR_ARRAY(0 to (MAX_STR_LEN - 1));

--Contains the length of the current string being sent over uart.
signal strEnd : natural;

--Contains the index of the next character to be sent over uart
--within the sendStr variable.
signal strIndex : natural;

--Used to determine when a button press has occured
signal btnReg : std_logic_vector (3 downto 0) := "0000";
signal btnDetect : std_logic;

--UART_TX_CTRL control signals
signal uartRdy : std_logic;
signal uartSend : std_logic := '0';
signal uartData : std_logic_vector (7 downto 0):= "00000000";
signal uartTX : std_logic;
signal uartRX : std_logic;

--Current uart state signal
signal uartState : UART_STATE_TYPE := RST_REG;

--Debounced btn signals used to prevent single button presses
--from being interpreted as multiple button presses.
signal btnDeBnc : std_logic_vector(4 downto 0);

signal CLKFX : std_logic;
signal CLK2X : std_logic;
signal RST	 : std_logic := '0';
signal CLKFBOUT : std_logic;
signal CLKOUT0 : std_logic;
signal CLKOUT1 : std_logic;
signal O : std_logic;
signal BUFG_O : std_logic;
signal IOCLK : std_logic;
signal PLL_BASE_LOCKED : std_logic;
signal DCM_CLKGEN_CLKFX : std_logic;

signal UART_tx_empty : std_logic;
signal UART_rx_empty : std_logic;
constant TMR_UART_MAX : std_logic_vector(13 downto 0) := "10100010101110"; --10416 = (round(100MHz / 9600)) - 1 поменьше
constant TMR_UART_RX_MAX : std_logic_vector(9 downto 0) := "1010001011"; --651 = (round(100MHz / 9600 / 16)) - 1 побольше
signal tmrUART : std_logic_vector(13 downto 0) := (others => '0');
signal tmrUART_RX : std_logic_vector(9 downto 0) := (others => '0');
signal UART_txclk : std_logic;
signal UART_rxclk : std_logic;
signal UART_uld_rx_data : std_logic;
signal UART_tx_enable : std_logic;
signal UART_ld_tx_data : std_logic;
signal UART_SEND_byte : std_logic := '0';
signal UART_READ_byte : std_logic := '0';
signal UART_READ_byte1 : std_logic := '0';
signal UART_SEND_byte_new : std_logic := '0';
signal UART_Data_tx : std_logic_vector (7 downto 0):= "00000000";
signal UART_reset : std_logic := '0';
signal UART_TX_BUSY : std_logic;
signal UART_RX_BUSY : std_logic;
signal UART_TX_VALID : std_logic;
signal UART_RX_VALID : std_logic;
signal UART_TEST		: std_logic;

--signal ADC_CLK			: std_logic;
signal ADC_Data		: std_logic_vector (11 downto 0);
signal ADC_RX_VALID	: std_logic;

signal ADC_val1		: integer range -127 to 127 := 10;
signal ADC_val2		: integer range -127 to 127 := 10;
signal ADC_int32_val1: integer range -2147483647 to 2147483647;
signal ADC_vec32_val1: std_logic_vector (31 downto 0);
signal ADC_float_val1: real :=1234.56789;
signal ADC_SUM			: integer range -32767 to 32767 := -12345;
signal ADC_SUM1		: std_logic_vector (15 downto 0);
signal ADC_SUM_state	: integer range 0 to 255;
signal ADC_SUM_valid	: std_logic := '0';
signal ADC_SUM_en		: std_logic := '0';
signal ADC_SUM_cntr	: integer range 0 to 1024;
signal ADC_SUM_cntr_N: integer range 0 to 1024;
signal ADC_SUM_float	: REAL range -1.0 to 1.0;
signal ADC_SUM_int32	: integer range -2147483647 to 2147483647;
signal ADC_SUM_vec32	: std_logic_vector (31 downto 0);
signal ADC_SUM_vec64	: std_logic_vector (63 downto 0);
signal ADC_SUM_vec64_buf: std_logic_vector (63 downto 0):=X"0000000000000000";
signal ADC_SUM_vec64_c	: std_logic_vector (63 downto 0);
signal ADC_SUM_vec64_buf_c: std_logic_vector (63 downto 0):=X"0000000000000000";
signal ADC_SIN_strob	: std_logic ;
signal ADC_SIN_strob_buf	: std_logic ;
signal ADC_SIN_strob_buf1	: std_logic ;
signal ADC_strob		: std_logic ;
signal ADC_state		: integer range 0 to 255 := 0;
signal ADC_cntr		: integer range 0 to 10000 := 0;
constant ADC_cntr_max : natural := 500;

signal DAC_Data		: std_logic_vector (11 downto 0) := X"0ff";

signal ODOM_ON		   : std_logic ;
signal ODOM_CNTR		: STD_LOGIC_VECTOR (15 downto 0) :=X"0000";
signal ODOM_CNTR_buf	: STD_LOGIC_VECTOR (15 downto 0) :=X"0000";


signal ETH_TX_EN_test: std_logic := '1';
signal ETH_TX_state	: integer range 0 to 255;
signal ETH_TX_pack_cntr : integer range 0 to 255 := 0;
signal ETH_TX_UDP_cntr 	: std_logic_vector (15 downto 0);
signal ETH_TX_DATA1 	: std_logic_vector (15 downto 0):= "0000000000000000";
signal ETH_TX_ADC		: std_logic := '0';
signal ETH_RST_cntr 	: std_logic_vector (7 downto 0):= "00000000";
signal UART_cntr_byte: integer range 0 to 100 := 0;
signal ETH_cntr 		: integer range 0 to 255 := EHT_PACK_LEN;
signal ETH_RX_cntr	: integer range 0 to 100 := 0;
signal ETH_LSB			: std_logic := '0';
signal ETH_RX_LSB		: std_logic := '0';
constant EHT_RX_PACK_LEN : natural := 256;
signal EHT_RX_PACK	: CHAR_ARRAY_1(0 to 255);
signal ETH_RX_DV_buf	: std_logic ;
signal ETH_RXD_1		: std_logic_vector(3 downto 0);
signal ETH_test_data	: std_logic_vector (0 to 7):= "00001111";
signal ETH_SMI_addr	: std_logic_vector(7 downto 0);
signal ETH_SMI_en		: std_logic := '0';
signal ETH_SMI_CLK	: std_logic := '0';
signal ETH_SMI_cntr	: std_logic_vector (7 downto 0):= "00000000";
signal ETH_tx_cntr	: integer range 0 to 50000000 := 0;
constant ETH_tx_cntr_max : natural := 100000;
signal ETH_TX_DATA		: std_logic_vector (15 downto 0):=X"0000";
signal ETH_TX_DATA_buf	: std_logic_vector (15 downto 0):=X"0000";
signal ETH_TX_DATA_write: std_logic := '0';
signal ETH_TX_DATA_write_buf 	: std_logic := '0';
signal ETH_TX_DATA_ADDR	: std_logic_vector (7 downto 0):=X"00";
signal ETH_TX_DATA_ADDR_buf	: std_logic_vector (7 downto 0):=X"00";

signal ETH_CRC_rstn	: std_logic := '1';
signal ETH_CRC_newFrame	: std_logic := '0';
signal ETH_CRC_newByte	: std_logic := '0';
signal ETH_CRC_byte	: std_logic_vector (7 downto 0);
signal ETH_CRC_valid	: std_logic ;
signal ETH_CRC_value	: std_logic_vector (31 downto 0);
signal ETH_CRC_value_1	: std_logic_vector (31 downto 0);
signal ETH_CRC_value_xor	: std_logic_vector (31 downto 0);
signal ETH_TX_pack_trans	: std_logic := '0';
signal ETH_TX_pack_trans_buf	: std_logic := '0';
signal ETH_CRC_state	: integer range 0 to 255;
signal ETH_CRC_state_vec	: std_logic_vector (7 downto 0);
signal ETH_CRC_cntr	: integer range 0 to 255;

signal SENSOR_VMT_buf	: std_logic ;

signal test1	: std_logic ;
signal test2	: std_logic ;

begin

with BTN(4) select
	LED <= SW 			when '0',
			 "00000000" when others;

with BTN(4) select
	SSEG_AN <= btnDeBnc(3 downto 0)	when '1', -- '0'
				  "1111" 			when others;

--This process controls the counter that triggers the 7-segment
--to be incremented. It counts 100,000,000 and then resets.		  

timer_counter_process : process (BUFG_O)
begin
	if (rising_edge(BUFG_O)) then
		if ((tmrCntr = TMR_CNTR_MAX) or (BTN(4) = '1')) then
			--tmrCntr <= (others => '0');
		else
			tmrCntr <= tmrCntr + 1;
		end if;
	end if;
end process;

--This process increments the digit being displayed on the 
--7-segment display every second.
timer_inc_process : process (BUFG_O)
begin
	if (rising_edge(BUFG_O)) then
		if (BTN(4) = '1') then
			tmrVal <= (others => '0');
		elsif (tmrCntr = TMR_CNTR_MAX) then
			if (tmrVal = TMR_VAL_MAX) then
				--tmrVal <= (others => '0');
			else
				tmrVal <= tmrVal + 1;
			end if;
		end if;
	end if;
end process;

--This select statement encodes the value of tmrVal to the necessary
--cathode signals to display it on the 7-segment
with tmrVal select
	SSEG_CA <= "11000000" when "0000",
				  "11111001" when "0001",
				  "10100100" when "0010",
				  "10110000" when "0011",
				  "10011001" when "0100",
				  "10010010" when "0101",
				  "10000010" when "0110",
				  "11111000" when "0111",
				  "10000000" when "1000",
				  "10010000" when "1001",
				  "11111111" when others;



btn_reg_process : process (BUFG_O)
begin
	if (rising_edge(BUFG_O)) then
		btnReg <= btnDeBnc(3 downto 0);
	end if;
end process;

--btnDetect goes high for a single clock cycle when a btn press is
--detected. This triggers a UART message to begin being sent.
btnDetect <= '1' when ((btnReg(0)='0' and btnDeBnc(0)='1') or
								(btnReg(1)='0' and btnDeBnc(1)='1') or
								(btnReg(2)='0' and btnDeBnc(2)='1') or
								(btnReg(3)='0' and btnDeBnc(3)='1')  ) else
				  '0';
				  

--Next Uart state logic (states described above)
next_uartState_process : process (BUFG_O)
begin
	if (rising_edge(BUFG_O)) then
		if (btnDeBnc(4) = '1') then
			uartState <= RST_REG;
		else	
			case uartState is 
			when RST_REG =>
				uartState <= LD_INIT_STR;
			when LD_INIT_STR =>
				uartState <= SEND_CHAR;
			when SEND_CHAR =>
				uartState <= RDY_LOW;
			when RDY_LOW =>
				uartState <= WAIT_RDY;
			when WAIT_RDY =>
				if (uartRdy = '1') then
					if (strEnd = strIndex) then
						uartState <= WAIT_BTN;
					else
						uartState <= SEND_CHAR;
					end if;
				end if;
			when WAIT_BTN =>
				if (btnDetect = '1') then
					uartState <= LD_BTN_STR;
				end if;
			when LD_BTN_STR =>
				uartState <= SEND_CHAR;
			when others=> --should never be reached
				uartState <= RST_REG;
			end case;
		end if ;
	end if;
end process;

--Loads the sendStr and strEnd signals when a LD state is
--is reached.
string_load_process : process (BUFG_O)
begin
	if (rising_edge(BUFG_O)) then
		if (uartState = LD_INIT_STR) then
			sendStr <= WELCOME_STR;
			strEnd <= WELCOME_STR_LEN;
		elsif (uartState = LD_BTN_STR) then
			sendStr(0 to 23) <= BTN_STR;
			strEnd <= BTN_STR_LEN;
		end if;
	end if;
end process;

--Conrols the strIndex signal so that it contains the index
--of the next character that needs to be sent over uart
char_count_process : process (BUFG_O)
begin
	if (rising_edge(BUFG_O)) then
		if (uartState = LD_INIT_STR or uartState = LD_BTN_STR) then
			strIndex <= 0;
		elsif (uartState = SEND_CHAR) then
			strIndex <= strIndex + 1;
		end if;
	end if;
end process;



--Debounces btn signals
Inst_btn_debounce: btn_debounce port map(
		BTN_I => BTN,
		CLK => CLK,
		BTN_O => btnDeBnc
	);


ETH_RST_process : process (CLK)
begin
	if (falling_edge(CLK)) then
--		if (tmrCntr = TMR_CNTR_MAX and ETH_RST_cntr < 5) then
--			ETH_RST <= '0';
--			--ETH_SMI_en <= '1';
--			--ETH_TXD_4 <='0';
--			ETH_TXD <= "ZZZZ";
--			--ETH_TX_EN <= '1';
--			ETH_RST_cntr <= ETH_RST_cntr + 1;
--		end if;
--		
--		if (tmrCntr = TMR_CNTR_MAX and ETH_RST_cntr = 5) then
--			ETH_RST <= '1';
--			ETH_RST_cntr <= ETH_RST_cntr + 1;
--		end if;
--		
--		if ( (ETH_RX_DV_buf = '1') and (ETH_RST_cntr = 6) ) then
--			ETH_SMI_en <= '1';
--			ETH_TXD_4 <='0'; 
--			ETH_RST_cntr <= ETH_RST_cntr + 1;			
--		end if;
--		
--		if (tmrCntr = TMR_CNTR_MAX and ETH_RST_cntr = 7 and uartData = X"f1") then
--			--ETH_SMI_en <= '1';
--			ETH_RST_cntr <= ETH_RST_cntr + 1;
--		end if;
		if ( tmrCntr < TMR_CNTR_MAX) then
			ETH_RST <= '0';
			ETH_RXD <= "0011";
			ETH_COL <= '1';
		end if;

		if ( tmrCntr = TMR_CNTR_MAX and ETH_RST_cntr < 2) then
			ETH_RST <= '1';
			--ETH_SMI_en <= '1';
			--ETH_TXD_4 <='0';
			--ETH_TXD <= "ZZZZ";
			--ETH_TX_EN <= '1';
			ETH_RST_cntr <= ETH_RST_cntr + 1;
		end if;
		
		
		if (tmrCntr = TMR_CNTR_MAX and ETH_RST_cntr = 2) then
			--ETH_RST <= '1';
			ETH_RXD <= "ZZZZ";
			ETH_RST_cntr <= ETH_RST_cntr + 1;
		end if;
		
	end if;
end process;

ETH_RX_DV_buf <= ETH_RX_DV;



--test1 <= ADC_SUM_en;
--test2 <= ETH_TXD(0);
--JB1_JB1 <= test1;
--JB1_JB2 <= test2;

ETH_MII_MEM_process : process (CLK)
begin
	if (rising_edge(CLK)) then
	
		if (ETH_SMI_en = '1' and ETH_SMI_addr < 128) then
			ETH_SMI_cntr <= ETH_SMI_cntr +1;
		else
			ETH_SMI_cntr <= "00000000";
			ETH_SMI_CLK <= '0';
		end if;
		
		if (ETH_SMI_cntr = "01111111") then
			ETH_SMI_CLK <= '1';
		elsif (ETH_SMI_cntr = "11111111") then
			ETH_SMI_CLK <= '0';
			ETH_SMI_addr <= ETH_SMI_addr + 1;
		end if;
		
	end if;
end process;

ETH_MDC <= ETH_SMI_CLK;

Inst_ETH_MII_MEM: ETH_MII_MEM port map(
      CLK   => ETH_SMI_CLK,       			
      en    => ETH_SMI_en,       			
      addr(6 downto 0)  => ETH_SMI_addr(6 downto 0), 		
      do 	=> ETH_MDIO 			
);

Inst_ETH: ETH port map(
      CLK   		=> CLK,       			
      ETH_TXD(3 downto 0)	=> ETH_TXD(3 downto 0),       			
      --ETH_TXD_4	=> ETH_TXD_4, 		
      ETH_TX_CLK 	=> ETH_TX_CLK ,
		ETH_TX_EN	=> ETH_TX_EN,
		
		ETH_RXD		=> ETH_RXD,
		ETH_RX_CLK	=> ETH_RX_CLK,
		ETH_RX_DV 	=> ETH_RX_DV,
		
		ETH_TX_DATA => ETH_TX_DATA,
		ETH_TX_DATA_write => ETH_TX_DATA_write,
		ETH_TX_DATA_ADDR	=> ETH_TX_DATA_ADDR,
		ETH_TX_pack_trans => ETH_TX_pack_trans
);


SENSOR_VMT_buf <= SENSOR_VMT;


ETH_TX_ADC_process : process (CLK)
begin
	if (rising_edge(CLK)) then

		if (ETH_tx_cntr >= ETH_tx_cntr_max) then
			ETH_tx_cntr <= 0;
		else
			ETH_tx_cntr <= ETH_tx_cntr + 1;
		end if;
		
		if (ADC_cntr >= ADC_cntr_max) then
			ADC_cntr <= 0;
		else
			ADC_cntr <= ADC_cntr + 1;
		end if;
		
		ETH_TX_DATA_ADDR 	<= ETH_TX_DATA_ADDR_buf;
		ETH_TX_DATA_write <= ETH_TX_DATA_write_buf;
		ETH_TX_pack_trans <= ETH_TX_pack_trans_buf;
		ETH_TX_DATA (15 downto 0) <= ETH_TX_DATA_buf (15 downto 0);
		
		
		case ADC_state is 
		when 0 =>
			ETH_TX_pack_trans_buf <= '0';
			ETH_TX_DATA_ADDR_buf  <= X"00";
			ETH_TX_DATA_write_buf <= '0';
			MUX <= (others => '0');
			ADC_state <= ADC_state + 1;
			
		when 1  =>												--одометр
			--if (ADC_cntr = 0) then
			if ((ETH_TX_DATA_write_buf = '0') and  ((ODOM_CNTR_buf (15 downto 0) /= ODOM_CNTR(15 downto 0)) or (SW(6) = '1') )) then
					ODOM_CNTR_buf (15 downto 0) <= ODOM_CNTR(15 downto 0);
					ETH_TX_DATA_buf (15 downto 0) <= ODOM_CNTR(15 downto 0);
					ETH_TX_DATA_write_buf <= '1';
				--end if;
			else 
				if (ETH_TX_DATA_write_buf = '1') then
					ETH_TX_DATA_ADDR_buf <= ETH_TX_DATA_ADDR_buf + 2;
					ETH_TX_DATA_write_buf <= '0';
					ADC_state <= ADC_state + 1;
				end if;
			end if;	

		when 2 =>												-- датчик ВМТ
			if (ETH_TX_DATA_write_buf = '0') then
				ETH_TX_DATA_buf (15 downto 0) <= "000000000000000" & SENSOR_VMT_buf;
				ETH_TX_DATA_write_buf <= '1';
			else
				ETH_TX_DATA_ADDR_buf <= ETH_TX_DATA_ADDR_buf + 2;
				ETH_TX_DATA_write_buf <= '0';
				ADC_state <= ADC_state + 1;
			end if;
		
		when 3 to 26 =>	--		1|2|3|4|5|6|7|8 =>	-- датчики вихри
			if (ADC_cntr = 0) then	
				ETH_TX_DATA_buf (11 downto 0) <= ADC_Data(11 downto 0);
				ETH_TX_DATA_write_buf <= '1';
				MUX <= MUX + 1;
			else 
				if (ETH_TX_DATA_write_buf = '1') then
					ETH_TX_DATA_ADDR_buf <= ETH_TX_DATA_ADDR_buf + 2;
					ETH_TX_DATA_write_buf <= '0';
					ADC_state <= ADC_state + 1;
				end if;				
			end if;
			
		when 27 =>
			if (ETH_RST_cntr > 2) then
				ETH_TX_pack_trans_buf <= '1';
			end if;
			ADC_state <= ADC_state + 1;
--			MUX <= (others => '0');
--			ETH_TX_DATA_write_buf <= '0';
--			ETH_TX_DATA_buf (15 downto 0) <= "0000000000000000";
--			ETH_TX_DATA_ADDR_buf  <= X"00";
--			if (ADC_cntr = 0) then	
--				ETH_TX_pack_trans_buf <= '1';
--				ADC_state <= ADC_state + 1;
--			end if;
		
		when others=>
			MUX <= (others => '0');
			ETH_TX_pack_trans_buf <= '0';
			if (ETH_tx_cntr = 0) then
				--ETH_TX_pack_trans_buf <= '1';
				ADC_state <= 0;
			end if;
		end case;
		
		
		
--		else
--			ETH_TX_DATA_write <= '0';
--		end if;
		
--			if (ADC_SUM_en = '1') then
--			ADC_strob <= not(ADC_strob);
--				if (ADC_strob = '0') then
--					--ADC_SUM_vec64_buf(11 downto 0) <= ADC_Data(11 downto 0);
--					ETH_TX_DATA (11 downto 0) <= ADC_Data(11 downto 0);
--					ETH_TX_DATA_ADDR <= 0;
--					ETH_TX_DATA_write <= '1';
--				else
--					--ADC_SUM_vec64_buf_c(11 downto 0) <= ADC_Data(11 downto 0);
--					ETH_TX_DATA (11 downto 0) <= ADC_Data(11 downto 0);
--					ETH_TX_DATA_ADDR <= 2;
--					ETH_TX_DATA_write <= '1';
--					ADC_SUM_valid <= '1';
--				end if;
--			else
--				ETH_TX_DATA_write <= '0';
--			end if;

--		case ADC_SUM_state is 
--		when 0 =>
--			if (ADC_SUM_en = '1') then
--				ADC_SUM_cntr <= 0;
--				ADC_SUM_cntr_N <= 0;
--				ADC_SUM_vec32 <= (others=>'0');
--				ADC_SUM_vec64(63 downto 0)  <= (others=>'0');
--				ADC_SUM_vec64_c(63 downto 0)  <= (others=>'0');
--				ADC_SUM_state <= ADC_SUM_state + 1;
--			end if;
--		when 1 =>
--			if (test1 = '1') then
--				ADC_SUM_state <= ADC_SUM_state + 1;
--			end if;
--		when 2 =>
--			if (ADC_RX_VALID = '1') then
--				ADC_SUM_vec64(63 downto 0) <= ADC_SUM_vec64(63 downto 0) + (conv_std_logic_vector( ( (conv_integer(ADC_Data) - 2048)* ((ADC_PACK_SIN(ADC_SUM_cntr_N) )) ),64 ));
--				ADC_SUM_vec64_c(63 downto 0) <= ADC_SUM_vec64_c(63 downto 0) + (conv_std_logic_vector( ( (conv_integer(ADC_Data) - 2048)* ((ADC_PACK_COS(ADC_SUM_cntr_N) )) ),64 ));
--				ADC_SUM_cntr_N <= ADC_SUM_cntr_N + 1;
--				ADC_SUM_cntr <= ADC_SUM_cntr + 1;				
--				if (ADC_SUM_cntr >= 99) then
--					ADC_SUM_state <= ADC_SUM_state + 1;
--				end if;
--			end if;
--		when 3 =>
--			--ADC_SUM_int32 <= INTEGER (ADC_SUM_float);
--			ADC_SUM_state <= ADC_SUM_state + 1;
--		when 4 =>
--			ADC_SUM_valid <= '1';
--			--ETH_TX_ADC <= '1';
--			ADC_SUM_vec64_buf(63 downto 0) <= ADC_SUM_vec64(63 downto 0);
--			ADC_SUM_vec64_buf_c(63 downto 0) <= ADC_SUM_vec64_c(63 downto 0);
--			ADC_SUM_state <= ADC_SUM_state + 1;
--		when others=>
--			ADC_SUM_state <= 0;
--		end case;

	end if;
end process;


UART_send_process : process (CLK)
begin
	if (rising_edge(CLK)) then
			if (UART_RX_VALID = '1') then
				UART_READ_byte1 <= '1';
			end if;
			
			if (ADC_RX_VALID = '1') then
				UART_READ_byte <= '1';
				if (UART_cntr_byte < EHT_PACK_LEN) then
					UART_cntr_byte <= UART_cntr_byte + 1;
				else
					UART_cntr_byte <= 0;
				end if;
			end if;
			
			--UART_TX_VALID <= '1';
			if (UART_READ_byte = '1') then
				--if(UART_TX_BUSY = '0') then
					UART_TX_VALID <= '1';
					UART_Data_tx(7 downto 0) <=  EHT_PACK(UART_cntr_byte)(7 downto 0); --ETH_RST_cntr(7 downto 0);--ADC_Data(7 downto 0) ;
					UART_READ_byte <= '0';
				--end if;
			elsif (UART_TX_BUSY = '0') then
				UART_TX_VALID <= '0';
			end if;
	end if;
end process;



UART_txclk <= '1' when (tmrUART = TMR_UART_MAX) else
				'0';
				
UART_rxclk <= '1' when ( tmrUART_RX = TMR_UART_RX_MAX) else
				'0';

	
Inst_UART: UART port map(
      CLK      => CLK,       			-- system clk
      RST_N    => '1',       			-- system reset#
      DATA_IN  => UART_Data_tx, 		-- Transmit data
      DATA_OUT => uartData, 			--Recieved data
      RX_VALID => UART_RX_VALID,    -- RX buffer data ready
      TX_VALID => UART_TX_VALID,    -- Data for TX avaible
      RXD      => uartRX,           -- RX pin
      TXD      => uartTX,        	-- TX pin
      TX_BUSY  => UART_TX_BUSY,    	-- TX pin
      RX_BUSY  => UART_RX_BUSY,
		TEST		=> UART_TEST
);

uartRX <= UART_RXD;
UART_TXD <= uartTX;
--JD1_JD7 <= UART_TEST;

Inst_ADC: ADC port map(
      CLK      => CLK,       -- system clk
		CLK_ADC	=> ADC_CLK,
      RST_N    => '0',       -- system reset#
		enable	=> '1',
      DATA_IN  => ADC_IN, -- 
      DATA_OUT => ADC_Data, --Recieved data
      RX_VALID => ADC_RX_VALID    -- RX buffer data ready
);

Inst_DAC: DAC port map(
      CLK      => CLK,       -- system clk
		CLK_DAC	=> DAC_CLK,
      RST_N    => '0',       -- system reset#
		enable	=> '1',
		LD			=> DAC_LD,
      DATA_IN  => DAC_DATA, 	-- Transmit data
      DATA_OUT1 => DAC_SDI1, 	-- Transmit data
		DATA_OUT2 => DAC_SDI2 	-- Transmit data
);


Inst_ODOM: ODOM port map(
      CLK      => CLK,       -- system clk
		ODOM_ON	=> ODOM_ON,  
		ODOM_CNTR => ODOM_CNTR,
		ODOM_DIR	=> ODOM_DIR,
		ODOM_CLK	=> ODOM_CLK
);

--DAC_SDI1	<= '0';
--DAC_SDI2	<= '0';
--DAC_LD	<= '0';

DCM_inst : DCM_SP
generic map (
CLKDV_DIVIDE => 2.0, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
-- 7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
CLKFX_DIVIDE => 1, -- Can be any interger from 1 to 32
CLKFX_MULTIPLY => 2, -- Can be any Integer from 1 to 32
CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
CLKIN_PERIOD => 10.0, -- Specify period of input clock
CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift of NONE, FIXED or VARIABLE
CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE, 1X or 2X
DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or
-- an Integer from 0 to 15
DFS_FREQUENCY_MODE => "LOW", -- HIGH or LOW frequency mode for frequency synthesis
DLL_FREQUENCY_MODE => "LOW", -- HIGH or LOW frequency mode for DLL
DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
FACTORY_JF => X"C080", -- FACTORY JF Values
PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 255
STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM_SP LOCK, TRUE/FALSE
port map (
--CLK0 => CLK0, -- 0 degree DCM_SP CLK ouptput
--CLK180 => CLK180, -- 180 degree DCM_SP CLK output
--CLK270 => CLK270, -- 270 degree DCM_SP CLK output
CLK2X => CLK2X, -- 2X DCM_SP CLK output
--CLK2X180 => CLK2X180, -- 2X, 180 degree DCM_SP CLK out
--CLK90 => CLK90, -- 90 degree DCM_SP CLK output
--CLKDV => CLKDV, -- Divided DCM_SP CLK out (CLKDV_DIVIDE)
CLKFX => CLKFX, -- DCM_SP CLK synthesis out (M/D)
--CLKFX180 => CLKFX180, -- 180 degree CLK synthesis out
--LOCKED => LOCKED, -- DCM_SP LOCK status output
--PSDONE => PSDONE, -- Dynamic phase adjust done output
--STATUS => STATUS, -- 8-bit DCM_SP status bits output
--CLKFB => CLKFB, -- DCM_SP clock feedback
CLKIN => DCM_CLKGEN_CLKFX, -- Clock input (from IBUFG, BUFG or DCM_SP)
--PSCLK => PSCLK, -- Dynamic phase adjust clock input
--PSEN => PSEN, -- Dynamic phase adjust enable input
--PSINCDEC => PSINCDEC, -- Dynamic phase adjust increment/decrement
RST => RST -- DCM_SP asynchronous reset input
);


DCM_CLKGEN_inst : DCM_CLKGEN
   generic map (
      CLKFXDV_DIVIDE => 2,       -- CLKFXDV divide value (2, 4, 8, 16, 32)
      CLKFX_DIVIDE => 1,         -- Divide value - D - (1-256)
      CLKFX_MD_MAX => 2.0,       -- Specify maximum M/D ratio for timing anlysis
      CLKFX_MULTIPLY => 2,       -- Multiply value - M - (2-256)
      CLKIN_PERIOD => 10.0,       -- Input clock period specified in nS
      SPREAD_SPECTRUM => "NONE", -- Spread Spectrum mode "NONE", "CENTER_LOW_SPREAD", "CENTER_HIGH_SPREAD",
                                 -- "VIDEO_LINK_M0", "VIDEO_LINK_M1" or "VIDEO_LINK_M2" 
      STARTUP_WAIT => FALSE      -- Delay config DONE until DCM_CLKGEN LOCKED (TRUE/FALSE)
   )
   port map (
      CLKFX => DCM_CLKGEN_CLKFX,         -- 1-bit output: Generated clock output
--      CLKFX180 => CLKFX180,   -- 1-bit output: Generated clock output 180 degree out of phase from CLKFX.
--      CLKFXDV => CLKFXDV,     -- 1-bit output: Divided clock output
--      LOCKED => LOCKED,       -- 1-bit output: Locked output
--      PROGDONE => PROGDONE,   -- 1-bit output: Active high output to indicate the successful re-programming
--      STATUS => STATUS,       -- 2-bit output: DCM_CLKGEN status
      CLKIN => CLK,         -- 1-bit input: Input clock
--      FREEZEDCM => FREEZEDCM, -- 1-bit input: Prevents frequency adjustments to input clock
--      PROGCLK => PROGCLK,     -- 1-bit input: Clock input for M/D reconfiguration
--      PROGDATA => PROGDATA,   -- 1-bit input: Serial data input for M/D reconfiguration
--      PROGEN => PROGEN,       -- 1-bit input: Active high program enable
      RST => RST              -- 1-bit input: Reset input pin
   );



PLL_BASE_inst : PLL_BASE
   generic map (
      BANDWIDTH => "OPTIMIZED",             -- "HIGH", "LOW" or "OPTIMIZED" 
      CLKFBOUT_MULT => 2,                   -- Multiply value for all CLKOUT clock outputs (1-64)
      CLKFBOUT_PHASE => 0.0,                -- Phase offset in degrees of the clock feedback output
                                            -- (0.0-360.0).
      CLKIN_PERIOD => 5.0,                  -- Input clock period in ns to ps resolution (i.e. 33.333 is 30
                                            -- MHz).
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
      CLKOUT0_DIVIDE => 1,
      CLKOUT1_DIVIDE => 1,
      CLKOUT2_DIVIDE => 1,
      CLKOUT3_DIVIDE => 1,
      CLKOUT4_DIVIDE => 1,
      CLKOUT5_DIVIDE => 1,
      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
      CLKOUT0_DUTY_CYCLE => 0.5,
      CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5,
      CLKOUT3_DUTY_CYCLE => 0.5,
      CLKOUT4_DUTY_CYCLE => 0.5,
      CLKOUT5_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
      CLKOUT0_PHASE => 0.0,
      CLKOUT1_PHASE => 0.0,
      CLKOUT2_PHASE => 0.0,
      CLKOUT3_PHASE => 0.0,
      CLKOUT4_PHASE => 0.0,
      CLKOUT5_PHASE => 0.0,
      CLK_FEEDBACK => "CLKFBOUT",           -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
      COMPENSATION => "SYSTEM_SYNCHRONOUS", -- "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
      DIVCLK_DIVIDE => 1,                   -- Division value for all output clocks (1-52)
      REF_JITTER => 0.1,                    -- Reference Clock Jitter in UI (0.000-0.999).
      RESET_ON_LOSS_OF_LOCK => FALSE        -- Must be set to FALSE
   )
   port map (
      CLKFBOUT => CLKFBOUT, -- 1-bit output: PLL_BASE feedback output
      ---- CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
      CLKOUT0 => CLKOUT0,
      CLKOUT1 => CLKOUT1,
      --CLKOUT2 => CLKOUT2,
      --CLKOUT3 => CLKOUT3,
      --CLKOUT4 => CLKOUT4,
      --CLKOUT5 => CLKOUT5,
      LOCKED => PLL_BASE_LOCKED,     -- 1-bit output: PLL_BASE lock status output
      CLKFBIN => CLKFBOUT,   -- 1-bit input: Feedback clock input
      CLKIN => DCM_CLKGEN_CLKFX,       -- 1-bit input: Clock input
      RST => RST            -- 1-bit input: Reset input
   );


-- <-----Cut code below this line and paste into the architecture body---->

   -- BUFG: Global Clock Buffer
   --       Spartan-6
   -- Xilinx HDL Language Template, version 13.2

   BUFG_inst : BUFG
   port map (
      O => BUFG_O, -- 1-bit output: Clock buffer output
      I => DCM_CLKGEN_CLKFX  -- 1-bit input: Clock buffer input
   );
	
	
-- <-----Cut code below this line and paste into the architecture body---->

   -- BUFPLL: High-speed I/O PLL clock buffer
   --         Spartan-6
   -- Xilinx HDL Language Template, version 13.2

--   BUFPLL_inst : BUFPLL
--   generic map (
--      DIVIDE => 1,         -- DIVCLK divider (1-8)
--      ENABLE_SYNC => TRUE  -- Enable synchrnonization between PLL and GCLK (TRUE/FALSE)
--   )
--   port map (
--      IOCLK => IOCLK,               -- 1-bit output: Output I/O clock
--      --LOCK => LOCK,                 -- 1-bit output: Synchronized LOCK output
--      --SERDESSTROBE => SERDESSTROBE, -- 1-bit output: Output SERDES strobe (connect to ISERDES2/OSERDES2)
--      GCLK => BUFG_O,                 -- 1-bit input: BUFG clock input
--      LOCKED => PLL_BASE_LOCKED,             -- 1-bit input: LOCKED input from PLL
--      PLLIN => CLKOUT0                -- 1-bit input: Clock input from PLL
--   );

end Behavioral;

