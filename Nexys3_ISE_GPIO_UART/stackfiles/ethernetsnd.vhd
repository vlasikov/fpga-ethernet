-------------------------------------------------------------------------------
-- ethernetsnd.vhd
--
-- Author(s):     Ashley Partis and Jorgen Peddersen
-- Created:       Jan 2001
-- Last Modified: Feb 2001
-- 
-- Sends frames to the PHY a nybble at a time to be sent over the network.
-- Any frame shorter that 46 bytes is forced to a length of 46 bytes and is
-- padded with whatever is currently in RAM at the time.  Sends both ARP and
-- IP frames.  The CRC is calculated as the bytes are sent and is sent at
-- the end.  Informs the layers above when it has transmitted their frame.
-- Pauses for over 12 bytes worth of data after each frame.
-- 
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.global_constants.all;

entity ethernetSnd is
    port (
        clk: in STD_LOGIC;										-- clock
        rstn: in STD_LOGIC;										-- asynchronous active low reset
        complete: in STD_LOGIC;									-- RAM operation complete signal
        rdData: in STD_LOGIC_VECTOR (7 downto 0);				-- read data bus from the RAM
        newFrame: in STD_LOGIC;									-- send a new frame signal
        frameSize: in STD_LOGIC_VECTOR (10 downto 0);			-- size of the frame to send
        destinationMAC: in STD_LOGIC_VECTOR (47 downto 0);		-- target MAC of the frame
        frameType: in STD_LOGIC;								-- type of the frame to send (ARP or IP)
        TX_CLK: in STD_LOGIC;									-- transmit clock from the PHY
        TX_EN: out STD_LOGIC;									-- transmit enable line to the PHY
        TX_DATA: buffer STD_LOGIC_VECTOR (3 downto 0);			-- transmit data line to the PHY
        rdRAM: out STD_LOGIC;									-- read RAM signal
        rdAddr: out STD_LOGIC_VECTOR (18 downto 0);				-- read address bus to the RAM
        frameSent: out STD_LOGIC      							-- frame sent signal to ARP
    );
end ethernetSnd;

architecture ethernetSnd_arch of ethernetSnd is

-- declaration of the CRC generator component
component crcGenerator is
    port (
    	clk: in STD_LOGIC;										-- Input clock
        rstn: in STD_LOGIC;										-- Asynchronous active low reset
        newFrame: in STD_LOGIC;									-- Assert to restart calculations
        newByte: in STD_LOGIC;									-- Assert to indicate a crcValid input byte
        inByte: in STD_LOGIC_VECTOR (7 downto 0);				-- Input byte
        crcValid: out STD_LOGIC;								-- Indicates crcValid CRC.  Active HIGH
        crcValue: out STD_LOGIC_VECTOR (31 downto 0)			-- CRC output
    );
end component;

-- state definitions
type STATETYPE is (stIdle, stWaitForTransCLKHI, stWaitForTransCLKLO, stSendPreambleCLKHI, stSendPreambleCLKLO, 
			stSendFrameHeaderCLKHI, stSendFrameHeaderCLKLO, stReadData,	stSendFrameHiNybbleCLKHI,
			stSendFrameHiNybbleCLKLO, stSendFrameLoNybbleCLKHI, stSendFrameLoNybbleCLKLO, stSetCRCHI, 
			stSetCRCLO, stLineWait);
signal presState: STATETYPE;
signal nextState: STATETYPE;

-- frame length buffer
signal frameLen: STD_LOGIC_VECTOR (10 downto 0);
signal nextFrameLen: STD_LOGIC_VECTOR (10 downto 0);

-- type of frame to send buffer (ARP or IP)
signal frameTypeLatch: STD_LOGIC;
signal nextFrameTypeLatch: STD_LOGIC;

-- destination MAC address latch signal and buffer
signal latchDestinationMAC: STD_LOGIC;
signal destinationMAClatch: STD_LOGIC_VECTOR (47 downto 0);

-- counter to send the data and headers
-- and signals to increment and reset the counter
signal cnt: STD_LOGIC_VECTOR (10 downto 0);
signal incCnt: STD_LOGIC;
signal rstCnt: STD_LOGIC;

-- signal to make TX_DATA a buffer
signal next_TX_DATA: STD_LOGIC_VECTOR (3 downto 0);

-- signal and buffer to latch and hold the data read from RAM
signal latchRdData: STD_LOGIC;
signal rdLatch: STD_LOGIC_VECTOR (7 downto 0);

-- buffer to avoid problems with the asynchronous input clock (to us) from the PHY
signal TX_CLKBuf: STD_LOGIC;

-- counter to create the required pause on the line after we've transmitted a frame
-- as well as an overflow signal and a reset signal
signal linePause: STD_LOGIC_VECTOR (10 downto 0);
signal rstLinePause: STD_LOGIC;
signal linePauseOverflow: STD_LOGIC;

-- signals for the CRC generator
signal CRC: STD_LOGIC_VECTOR (31 downto 0);
signal newCRCByte: STD_LOGIC;
signal CRCByte: STD_LOGIC_VECTOR (7 downto 0);
signal CRCNewFrame: STD_LOGIC;

begin

	-- instantiate the CRC generator
	EthernetSendCRCGen : crcGenerator port map (
    	clk => clk,
        rstn => rstn,
        newFrame => CRCnewFrame,
        newByte => newCRCByte,
        inByte => CRCByte,
        crcValid => open,
        crcValue => CRC
    );
	
	-- main clocked process
	process (clk, rstn)
	begin
		-- set up the asynchronous active low reset by defaulting to the idle state
		if rstn = '0' then
			presState <= stIdle;
		elsif clk'event and clk = '1' then
			presState <= nextState;
			-- set up frameLen, frameTypeLatch and TX_DATA buffers with their next signals
			frameLen <= nextFrameLen;
			frameTypeLatch <= nextFrameTypeLatch;
			TX_DATA <= next_TX_DATA;
			-- latch data from RAM when reads are finished
			if latchRdData = '1' then
				rdLatch <= rdData;
			end if;
			-- latch the destinationMAC input to remembed where to send the frame
			if latchDestinationMAC = '1' then
				destinationMACLatch <= destinationMAC;
			end if;
			-- increment and reset the counter synchronously to avoid race conditions
			if incCnt = '1' then
				cnt <= cnt + 1;
			elsif rstCnt = '1' then
				cnt <= (others => '0');
			end if;
			-- reset the pause counter (which creates a pause of 12 octets on the line) to
			-- 1, which will then automatically increment till it reaches 0 again
			-- set the overflow signal when it is at 0
			if rstLinePause = '1' then
				linePause <= "000" & x"01";
				linePauseOverflow <= '0';
			elsif linePause = 0 then
				linePauseOverflow <= '1';
			else
				linePause <= linePause + 1;
				linePauseOverflow <= '0';
			end if;
			-- buffer the asynchronous clock input from the PHY to avoid timing violations,
			-- which would result in potential lockups
			if TX_CLK = '1' then
				TX_CLKBuf <= '1';
			else
				TX_CLKBuf <= '0';
			end if;
		end if;
	end process;

	-- main FSM process
	process (presState, newFrame, frameLen, CRC, TX_DATA, rdLatch, complete, frameSize, 
			TX_CLKBuf, cnt, destinationMACLatch, frameTypeLatch, frameType, linePauseOverflow)
	begin
		-- signal defaults
		rstcnt <= '0';
		incCnt <= '0';
		-- default transmit enable to high, as it only needs to be low in few states
		TX_EN <= '1';
		-- remember the previous value of frameLen, TX_DATA and frameTypeLatch by default
		nextFrameLen <= frameLen;
		next_TX_DATA <= TX_DATA;
		nextFrameTypeLatch <= frameTypeLatch;
		latchDestinationMAC <= '0';
		rdRam <= '0';
		rdAddr <= (others => '0');
		latchRdData <= '0';
		newCRCByte <= '0';
		CRCByte <= (others => '0');
		CRCNewFrame <= '0';
		rstLinePause <= '0';
		frameSent <= '0';
		
		case presState is
			when stIdle =>
				-- wait for a new frame to be ready to transmit
				if newFrame = '0' then
					nextState <= stIdle;
					rstCnt <= '1';
					TX_EN <= '0';		-- keep transmit enable low till we are ready to transmit
				else
					nextState <= stWaitForTransCLKLO;
					-- if the frame size is less than the minimum size of 46 bytes (for ethernet),
					-- then set the frame size to 46
					if frameSize > 46 then
						nextFrameLen <= frameSize;
					else
						nextFrameLen <= "000" & x"2E";
					end if;
					-- reset the CRC generator
					CRCNewFrame <= '1';
					TX_EN <= '0';
					-- latch the destination MAC and frame type inputs
					latchDestinationMAC <= '1';
					nextFrameTypeLatch <= frameType;
				end if;
				
			when stWaitForTransCLKLO =>
				-- wait for TX_CLKBuf to hit a falling edge before we start
				-- make sure it is high before we continue
				-- this is because the PHY latches the data on the rising edge, so 
				-- we set it on the falling edge
				-- still keep transmit enable low until we assert the first nybble to send
				if TX_CLKBuf = '0' then
					nextState <= stWaitForTransCLKLO;
					TX_EN <= '0';
				else
					nextState <= stWaitForTransCLKHI;
					TX_EN <= '0';
				end if;

			when stWaitForTransCLKHI =>
				-- wait for TX_CLKBuf to hit a falling edge before we start
				-- allow TX_EN to go high
				if TX_CLKBuf = '0' then
					nextState <= stSendPreambleCLKLO;
					-- set the lower nybble of the first byte of the preamble
					next_TX_DATA <= x"5";
					incCnt <= '1';
				-- wait while TX_CLKBuf is still high
				else
					nextState <= stWaitForTransCLKHI;
					TX_EN <= '0';
				end if;
				
			when stSendPreambleCLKLO =>
				-- wait for another falling edge
				-- do nothing in TX_CLKBuf low time and on the rising edge
				if TX_CLKBuf = '0' then
					nextState <= stSendPreambleCLKLO;
				else
					nextState <= stSendPreambleCLKHI;
				end if;
			
			when stSendPreambleCLKHI =>
				-- when there's a falling edge, set the data
				if TX_CLKBuf = '0' then
					-- send the last nybble of the preamble
					-- we've finished the preamble, so start sending the headers
					if cnt = 15 then
						next_TX_DATA <= x"D";
						nextState <= stSendFrameHeaderCLKLO;
						rstCnt <= '1';
					-- send a preamble of alternating 1s and 0s, low bit gets sent first
					-- so the preamble consists of a series of 7 "5"s followed by "5D" - 
					-- the last two ones in the D tell it that the frame is about to follow
					else
						next_TX_DATA <= x"5";
						nextState <= stSendPreambleCLKLO;
						incCnt <= '1';
					end if;
				-- wait for the falling edge of TX_CLKBuf
				else
					nextState <= stSendPreambleCLKHI;
				end if;
			
			when stSendFrameHeaderCLKLO =>
				-- wait for another falling edge
				-- do nothing in TX_CLKBuf low time
				if TX_CLKBuf = '0' then
					nextState <= stSendFrameHeaderCLKLO;
				else
					nextState <= stSendFrameHeaderCLKHI;
				end if;
			
			when stSendFrameHeaderCLKHI =>
				-- if we've seen a falling edge, then set the next nybble of the header to send
				if TX_CLKBuf = '0' then
					-- if we've sent all 28 nybbles of the header, then start sending the data
					-- otherwise, keep sending the header
					if cnt (4 downto 0) = '1' & x"B" then			
						nextState <= stReadData;
						rstCnt <= '1';
						incCnt <= '0';
					else
						nextState <= stSendFrameHeaderCLKLO;
						incCnt <= '1';
					end if;
					-- set the headers according to cnt, a nybble at a time
					case cnt (4 downto 0) is
						-- first byte of destination MAC address (low nybble first)
						when '0' & x"0" =>
							next_TX_DATA <= destinationMACLatch (43 downto 40);

						-- also send each byte to the CRC generator to create the CRC using
						-- newCRCByte and CRCByte
						when '0' & x"1" =>
							next_TX_DATA <= destinationMACLatch (47 downto 44);
							newCRCByte <= '1';
							CRCByte <= destinationMACLatch (47 downto 40);
						
						-- second byte of destination MAC address
						when '0' & x"2" =>
							next_TX_DATA <= destinationMACLatch(35 downto 32);
						
						when '0' & x"3" =>
							next_TX_DATA <= destinationMACLatch(39 downto 36);
							newCRCByte <= '1';
							CRCByte <= destinationMACLatch(39 downto 32);
							
						-- third byte of destination MAC address
						when '0' & x"4" =>
							next_TX_DATA <= destinationMACLatch(27 downto 24);
						
						when '0' & x"5" =>
							next_TX_DATA <= destinationMACLatch(31 downto 28);
							newCRCByte <= '1';
							CRCByte <= destinationMACLatch(31 downto 24);
						
						-- fourth byte of destination MAC address
						when '0' & x"6" =>
							next_TX_DATA <= destinationMACLatch(19 downto 16);
													
						when '0' & x"7" =>
							next_TX_DATA <= destinationMACLatch(23 downto 20);
							newCRCByte <= '1';
							CRCByte <= destinationMACLatch(23 downto 16);
						
						-- fifth byte of destination MAC address
						when '0' & x"8" =>
							next_TX_DATA <= destinationMACLatch(11 downto 8);
						
						when '0' & x"9" =>
							next_TX_DATA <= destinationMACLatch(15 downto 12);
							newCRCByte <= '1';
							CRCByte <= destinationMACLatch(15 downto 8);
							
						-- sixth byte of destination MAC address
						when '0' & x"A" =>
							next_TX_DATA <= destinationMACLatch(3 downto 0);
							
						when '0' & x"B" =>
							next_TX_DATA <= destinationMACLatch(7 downto 4);
							newCRCByte <= '1';
							CRCByte <= destinationMACLatch(7 downto 0);
							
						-- first byte of source MAC address
						when '0' & x"C" =>
							next_TX_DATA <= DEVICE_MAC(43 downto 40);
						
						when '0' & x"D" =>
							next_TX_DATA <= DEVICE_MAC(47 downto 44);
							newCRCByte <= '1';
							CRCByte <= DEVICE_MAC(47 downto 40);
						
						-- second byte of source MAC address
						when '0' & x"E" =>
							next_TX_DATA <= DEVICE_MAC(35 downto 32);
						
						when '0' & x"F" =>
							next_TX_DATA <= DEVICE_MAC(39 downto 36);
							newCRCByte <= '1';
							CRCByte <= DEVICE_MAC(39 downto 32);
						
						-- third byte of source MAC address
						when '1' & x"0" =>
							next_TX_DATA <= DEVICE_MAC(27 downto 24);
						
						when '1' & x"1" =>
							next_TX_DATA <= DEVICE_MAC(31 downto 28);
							newCRCByte <= '1';
							CRCByte <= DEVICE_MAC(31 downto 24);
						
						-- fourth byte of source MAC address
						when '1' & x"2" =>
							next_TX_DATA <= DEVICE_MAC(19 downto 16);
							
						when '1' & x"3" =>
							next_TX_DATA <= DEVICE_MAC(23 downto 20);
							newCRCByte <= '1';
							CRCByte <= DEVICE_MAC(23 downto 16);

						-- fifth byte of source MAC address
						when '1' & x"4" =>
							next_TX_DATA <= DEVICE_MAC(11 downto 8);

						when '1' & x"5" =>
							next_TX_DATA <= DEVICE_MAC(15 downto 12);
							newCRCByte <= '1';
							CRCByte <= DEVICE_MAC(15 downto 8);

						-- sixth byte of source MAC address
						when '1' & x"6" =>
							next_TX_DATA <= DEVICE_MAC(3 downto 0);

						when '1' & x"7" =>
							next_TX_DATA <= DEVICE_MAC(7 downto 4);
							newCRCByte <= '1';
							CRCByte <= DEVICE_MAC(7 downto 0);

						-- ethernet type field byte one
						when '1' & x"8" =>
							next_TX_DATA <= x"8";

						when '1' & x"9" =>
							next_TX_DATA <= x"0";
							newCRCByte <= '1';
							CRCByte <= x"08";

						-- ethernet type field byte two - 0 for IP and 6 for ARP (0000 or 0110)
						when '1' & x"A" =>
							next_TX_DATA <= '0' & NOT frameTypeLatch & NOT frameTypeLatch & '0';
							CRCByte <= "00000" & NOT frameTypeLatch & NOT frameTypeLatch & '0';
							newCRCByte <= '1';

						-- after setting the last nybble, start sending the actual frame data
						when '1' & x"B" =>
							next_TX_DATA <= x"0";

						when others =>
					end case;
				else
					nextState <= stSendFrameHeaderCLKHI;
				end if;
				
			when stReadData =>
				-- get the next byte of data from RAM, and latch it
				if complete = '0' then
					nextState <= stReadData;
					rdRAM <= '1';
					-- depending on the frame type, either pull the data from the ARP buffer or IP buffer
					if frameTypeLatch = '1' then
						rdAddr <= "00000001" & cnt;
					else
						rdAddr <= "00000000" & cnt;
					end if;
				else
					nextState <= stSendFrameLoNybbleCLKLO;
					latchRdData <= '1';
					-- increment the address counter
					incCnt <= '1';
				end if;
			
			when stSendFrameLoNybbleCLKLO =>
				-- wait for another falling edge
				-- do nothing in TX_CLKBuf low time
				if TX_CLKBuf = '0' then
					nextState <= stSendFrameLoNybbleCLKLO;
				else
					nextState <= stSendFrameHiNybbleCLKHI;
					-- send the data just read to the CRC generator
					newCRCByte <= '1';
					CRCByte <= rdLatch;
				end if;


			when stSendFrameHiNybbleCLKHI =>
				-- wait for the falling edge, then set TX_DATA
				if TX_CLKBuf = '0' then
					nextState <= stSendFrameHiNybbleCLKLO;
					next_TX_DATA <= rdLatch (3 downto 0);
					-- the CRC generator needs four bytes of 0s sent to it after we
					-- finish sending it the frame data (ie count = frame length) to 
					-- correctly calculate the CRC
					-- it needs 8 clock cycles to process each byte
					-- send the first byte 0s needed for the CRC
					if cnt = frameLen then
						newCRCByte <= '1';
						CRCByte <= x"00";
					end if;
				else
					nextState <= stSendFrameHiNybbleCLKHI;
				end if;
			
			when stSendFrameHiNybbleCLKLO =>
				-- do nothing when the transmit clock is low
				if TX_CLKBuf = '0' then
					nextState <= stSendFrameHiNybbleCLKLO;
				else
					nextState <= stSendFrameLoNybbleCLKHI;
					-- send the second byte of 0s needed for the CRC to the CRC generator, 
					-- once all the data has been sent
					if cnt = frameLen then
						newCRCByte <= '1';
						CRCByte <= x"00";
					end if;
				end if;

			when stSendFrameLoNybbleCLKHI =>
				-- on the falling edge send the lower nybble of data
				if TX_CLKBuf = '0' then
					-- if we've finished sending the data, prepare to send the CRC
					-- after setting the last nybble of data
					if cnt = frameLen then
						nextState <= stSetCRCLO;
						rstCnt <= '1';
						-- send the third byte of 0s needed for the CRC to the CRC generator
						newCRCByte <= '1';
						CRCByte <= x"00";
					-- otherwise keep reading and sending data
					else
						nextState <= stReadData;
					end if;
					next_TX_DATA <= rdLatch (7 downto 4);
				-- wait for the falling edge
				else
					nextState <= stSendFrameLoNybbleCLKHI;
				end if;
			
			when stSetCRCLO =>
				if TX_CLKBuf = '0' then
					-- once we've sent the CRC, make sure we don't send anything else for
					-- a while, and inform the next layer that the frame has been sent, and
					-- take transmit enable back to low
					if cnt = 9 then 
						nextState <= stLineWait;
						frameSent <= '1';
						rstLinePause <= '1';
						TX_EN <= '0';
					else
						nextState <= stSetCRCLO;
					end if;
				else
					nextState <= stSetCRCHI;
					-- send the fourth byte of zeros needed to the CRC generator
					-- the CRC should be ready now for the next falling edge so we
					-- can send it
					if cnt = 0 then
						newCRCByte <= '1';
						CRCByte <= x"00";
					end if;
				end if;
			
			when stSetCRCHI =>
				-- set the CRC on the falling edge, low byte first
				if TX_CLKBuf = '0' then
					nextState <= stSetCRCLO;
					incCnt <= '1';
					case cnt (2 downto 0) is
						when "000" =>
							next_TX_DATA <= CRC (3 downto 0);

						when "001" =>
							next_TX_DATA <= CRC (7 downto 4);

						when "010" =>
							next_TX_DATA <= CRC (11 downto 8);

						when "011" =>
							next_TX_DATA <= CRC (15 downto 12);

						when "100" =>
							next_TX_DATA <= CRC (19 downto 16);

						when "101" =>
							next_TX_DATA <= CRC (23 downto 20);

						when "110" =>
							next_TX_DATA <= CRC (27 downto 24);

						when "111" =>
							next_TX_DATA <= CRC (31 downto 28);

						when others =>
					end case;
				-- wait for the falling edge
				else
					nextState <= stSetCRCHI;
				end if;
			
			when stLineWait =>
				-- wait for linePause to overflow before being able to send another frame
				-- make sure we're not still trying to transmit by keeping transmit enable low
				TX_EN <= '0';
				if linePauseOverflow = '1' then
					nextState <= stIdle;
				else
					nextState <= stLineWait;
				end if;

			when others =>
		end case;	
	end process;
end ethernetSnd_arch;
