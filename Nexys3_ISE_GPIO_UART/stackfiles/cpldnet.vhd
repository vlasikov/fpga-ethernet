library ieee;
use ieee.std_logic_1164.all;

entity dwnldpar is
	port(
		-- parallel port data, control, and status pins
		ppd: in std_logic_vector(7 downto 0);
		ppc: in std_logic_vector(3 downto 0);
		pps: out std_logic_vector(6 downto 3);

		-- Virtex FPGA pins
		V_a: in std_logic_vector(3 downto 0);	-- inputs from Virtex
		V_tck: out std_logic;	-- driver to Virtex JTAG clock
		V_cclk: out std_logic;	-- driver to Virtex config clock
		V_progb: out std_logic;	-- driver to Virtex program pin
--		V_initb: in std_logic;	-- input from Virtex init pin
		V_done: in std_logic;	-- input from Virtex done pin
		V_d: out std_logic_vector(7 downto 0);	-- drivers to Virtex data pins
		V_m: out std_logic_vector(2 downto 0);	-- Virtex config mode pins

		ceb: out std_logic;		-- Flash chip-enable
		resetb: out std_logic;	-- reset for video input and Ethernet chips
		
		-- Ethernet control lines
		ledsb: in std_logic;
		ledrb: in std_logic;
		ledtb: in std_logic;
		ledlb: in std_logic;
		cfg: out std_logic_vector(1 downto 0);
		mf: out std_logic_vector(4 downto 0);
		fde: out std_logic;
		mddis: out std_logic; 
		
		rs: out std_logic_vector(6 downto 0);	-- Right hex display
		bar: out std_logic_vector(9 downto 0)	-- LED bargraph
	);
end dwnldpar;

architecture dwnldpar_arch of dwnldpar is
	constant LO: std_logic := '0';
	constant HI: std_logic := '1';
	constant SLAVE_SERIAL_MODE: std_logic_vector(2 downto 0) := "111";
begin
	-- disable other chips on the XSV Board so they don't interfere
	-- during the configuration of the Virtex FPGA
	ceb		<= HI;	-- disable Flash
	V_tck	<= LO;	-- deactivate Virtex JTAG circuit
	-- disable the video input and Ethernet chips until config is done
	resetb	<= LO when V_done=LO else HI;

	-- connect Virtex configuration pins
	V_m		<= SLAVE_SERIAL_MODE;	-- set Virtex config mode pins
	V_progb	<= ppc(0);	-- Virtex programming pulse comes from parallel port
	V_cclk	<= ppc(1);	-- Virtex config clock comes from parallel port
	-- config bitstream comes from parallel port control pin until 
	-- config is done and then gets driven by parallel port data pin 
	V_d(0)	<= ppc(3) when V_done=LO else ppd(0);

	-- connect the rest of the parallel port to the Virtex FPGA
	V_d(7 downto 1) <= ppd(7 downto 1);	-- data from PC
	pps(6 downto 3) <= V_a(3 downto 0);	-- status back to PC

	-- control ethernet chip
	mddis <= HI;
	fde <= HI;
	cfg(0) <= LO;
	cfg(1) <= LO;
	mf(0) <= LO;
	mf(1) <= LO;
	mf(2) <= LO;
	mf(3) <= HI;
	mf(4) <= LO;

	-- display status of Ethernet device on bargraph LEDs and display
	bar(0) <= ledrb;
	bar(1) <= ledtb;
	rs(5) <= ledsb;
	rs(6) <= ledlb;
--	bar(0) <= V_done;
--	bar(1) <= V_initb;
end dwnldpar_arch;

