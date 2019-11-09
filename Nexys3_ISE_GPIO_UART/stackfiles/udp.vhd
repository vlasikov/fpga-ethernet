-------------------------------------------------------------------------------
-- udp.vhd
--
-- Author(s):     Ashley Partis
-- Created:       Feb 2001
-- Last Modified: Feb 2001
-- 
-- Simple UDP receive interface.  Stores UDP data to a specific location.
-- Doesn't do much without some application making use of it.  Sample of what
-- can be done to utilise UDP.
--
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity udp is
    port (
		clk: in STD_LOGIC;								-- clock
		rstn: in STD_LOGIC;								-- asychronous active low reset
		protocol: in STD_LOGIC_VECTOR (7 downto 0);		-- protocol of the datagram from the internet layer
		newDatagram: in STD_LOGIC;						-- new datagram signal from the internet layer
		sourceIP: in STD_LOGIC_VECTOR (31 downto 0);	-- IP address of the sender
		IPbuffer: in STD_LOGIC;							-- which buffer the IP address was stored in
		complete: in STD_LOGIC;							-- RAM read / write complete signal
		rdData: in STD_LOGIC_VECTOR (7 downto 0);		-- read data bus to the RAM
		rdRAM: out STD_LOGIC;							-- read RAM signal
		rdAddr: out STD_LOGIC_VECTOR (18 downto 0);		-- read RAM address bua
		wrRAM: out STD_LOGIC;							-- write RAM signal
		wrData: out STD_LOGIC_VECTOR (7 downto 0);		-- write data bus to the RAM
		wrAddr: out STD_LOGIC_VECTOR (18 downto 0);		-- write address bus to the RAM
		sourceIPOut: out STD_LOGIC_VECTOR (31 downto 0)	-- IP address of the sender
    );
end udp;

architecture udp_arch of udp is

-- state declarations
type STATETYPE is (stIdle, stGetUDPHeader, stStoreUDPHeader, stGetUDPData, stWriteUDPData);
signal presState: STATETYPE;
signal nextState: STATETYPE;

-- signal and buffers to latch and hold the outputs of the internet layer
signal latchData: STD_LOGIC;
signal sourceIPLatch: STD_LOGIC_VECTOR (31 downto 0);
signal IPSourceBuffer: STD_LOGIC_VECTOR (1 downto 0);

-- counter to store off the data in the transport PDU, and signals to reset and increment it
signal cnt: STD_LOGIC_VECTOR (15 downto 0);
signal incCnt: STD_LOGIC;
signal rstCnt: STD_LOGIC;

-- signal and buffer to latch and hold the data from the RAM read data bus 
signal latchRdData: STD_LOGIC;
signal rdLatch: STD_LOGIC_VECTOR (7 downto 0);

-- latch the source and destination ports, for use somewhere?
signal sourcePort: STD_LOGIC_VECTOR (15 downto 0);
signal nextSourcePort: STD_LOGIC_VECTOR (15 downto 0);
signal destPort: STD_LOGIC_VECTOR (15 downto 0);
signal nextDestPort: STD_LOGIC_VECTOR (15 downto 0);

-- signals to hold the length of the transport protocol data unit, as obtained from the header
signal PDULen: STD_LOGIC_VECTOR (15 downto 0);
signal nextPDULen: STD_LOGIC_VECTOR (15 downto 0);

begin

	-- main clocked process
A:	process (clk, rstn)
	begin
		-- reset the FSM on the asychronous active low reset
		if rstn = '0' then
			presState <= stIdle;
		elsif clk'event and clk = '1' then
			presState <= nextState;
			-- remember the source port, destination port, and length
			sourcePort <= nextSourcePort;
			destPort <= nextDestPort;
			PDULen <= nextPDULen;
			-- when latch data is asserted, latch the source IP inputs and source IP buffer
			-- set the source IP buffer to be at either 10000h or 20000h
			if latchData = '1' then
				sourceIPLatch <= sourceIP;
				IPSourceBuffer <= (0 => NOT IPBuffer, 1 => IPBuffer);
			end if;
			-- when read data latch is asserted, latch the data from the RAM
			if latchRdData = '1' then
				rdLatch <= rdData;
			end if;
			-- increment and reset the counter sychronously to avoid race conditions
			if incCnt = '1' then
				cnt <= cnt + 1;
			elsif rstCnt = '1' then
				cnt <= (others => '0');
			end if;
		end if;
	end process;	-- end process A

	-- set the RAM signals that never change
	rdAddr <= '0' & IPSourceBuffer & cnt;
	wrData <= rdLatch;
	wrAddr <= "011" & cnt - 8;

B:	process (presState, destPort, sourcePort, complete, rdLatch, cnt, protocol, PDULen, newDatagram,
			sourceIPLatch)
	begin
		-- signal defaults
		latchData <= '0';
		rstCnt <= '0';
		incCnt <= '0';
		latchRdData <= '0';
		-- remember these signals
		nextDestPort <= destPort;
		nextSourcePort <= sourcePort;
		nextPDULen <= PDULen;
		rdRAM <= '0';
		wrRAM <= '0';
		sourceIPOut <= (others => '0');
	
		case (presState) is
			when stIdle =>
				-- if a new datagram has arrived, and it is has the UDP protocol, then we deal with it
				if protocol = x"11" and newDatagram = '1' then
					nextState <= stGetUDPHeader;
					latchData <= '1';
				-- otherwise, ignore it
				else
					nextState <= stIdle;
					rstCnt <= '1';
				end if;

			when stGetUDPHeader =>
				-- get the UDP header from RAM
				if complete = '0' then
					nextState <= stGetUDPHeader;
					rdRAM <= '1';
				else
					nextState <= stStoreUDPHeader;
					latchRdData <= '1';
				end if;
				
			when stStoreUDPHeader =>
				nextState <= stGetUDPHeader;
				incCnt <= '1';
				-- act appropriately on each header byte
				case cnt(2 downto 0) is
					-- latch the source port MSB
					when "000" =>
						nextSourcePort (15 downto 8) <= rdLatch;
						
					-- latch the source port LSB
					when "001" =>
						nextSourcePort (7 downto 0) <= rdLatch;
						
					-- latch the destination port MSB
					when "010" =>
						nextDestPort (15 downto 8) <= rdLatch;
						-- check the source port
--						if sourcePort /= x"8A" then
--							nextState <= stIdle;
--						end if;
					
					-- latch the destination port LSB
					when "011" =>
						nextDestPort (7 downto 0) <= rdLatch;
					
					-- latch the length of the TPDU MSB
					when "100" =>
						-- check the destination port
--						if destPort /= x"8A" then
--							nextState <= stIdle;
--						end if;
						nextPDULen (15 downto 8) <= rdLatch;
					
					-- latch the TPDU LSB
					when "101" =>
						nextPDULen (7 downto 0) <= rdLatch;
					
					-- ignore the checksum
					when "110" =>
						
					when "111" =>
						-- get the data once the headers have finished being processed
						nextState <= stGetUDPData;
					
					when others =>
				end case;
					
			when stGetUDPData =>
				-- if we've operated on all the data, then finish
				if cnt = PDULen then
					nextState <= stIdle;
					sourceIPOut <= sourceIPLatch;
				-- otherwise, grab data from RAM
				elsif complete = '0' then
					nextState <= stGetUDPData;
					rdRAM <= '1';
				else
					nextState <= stWriteUDPData;
					latchRdData <= '1';
				end if;

			when stWriteUDPData =>
				-- write the data we just grabbed from RAM to our UDP buffer
				if complete = '0' then
					nextState <= stWriteUDPData;
					wrRAM <= '1';
				else
					nextState <= stGetUDPData;
					incCnt <= '1';
				end if;

					
		when others =>
		end case;
	
	end process; -- end process B
end udp_arch;
