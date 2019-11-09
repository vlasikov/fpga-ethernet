-------------------------------------------------------------------------------
-- ethernet.vhd
--
-- Author(s):     Ashley Partis and Jorgen Peddersen
-- Created:       Jan 2001
-- Last Modified: Feb 2001
-- 
-- Receives frames from the PHY chip and passes them to the next layer(s)
-- using a bytestream.  Only allows valid IP frames and ARP frames.  Frames
-- with incorrect CRCs are declared invalid.  Frames with MACs that are not
-- broadcasts or the same as in the global_constants are ignored.  RX_ERR is
-- ignored.
--
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.global_constants.all;

entity ethernet is
    port (
		clk: in STD_LOGIC;								-- clock
		rstn: in STD_LOGIC;								-- asynchornous active low reset
		RX_DATA: in STD_LOGIC_VECTOR (3 downto 0);		-- 4 bit receive data line from the ethernet PHY
		RX_DV: in STD_LOGIC;							-- PHY receive data valid signal
--		RX_ERR: in STD_LOGIC;							-- PHY receive error signal
		RX_CLK: in STD_LOGIC;							-- PHY receiver clock
		frameType: out STD_LOGIC;						-- Inform the ARP or IP processes when we have a byte
		frameByte: out STD_LOGIC;						-- signal to write data to IP layer
		frameData: out STD_LOGIC_VECTOR (7 downto 0);	-- data to write to the IP layer
		newFrame: out STD_LOGIC;						-- new frame signal to the next layer
		endFrame: out STD_LOGIC;						-- end of frame signal to the next layer
		frameValid: out STD_LOGIC						-- indicate if the frame is valid (assert with endFrame)
	);
end Ethernet;

architecture ethernet_arch of Ethernet is

component crcGenerator is
    port (
    	clk: in STD_LOGIC;								-- Input clock
        rstn: in STD_LOGIC;								-- Asynchronous active low reset
        newFrame: in STD_LOGIC;							-- Assert to restart calculations
        newByte: in STD_LOGIC;							-- Assert to indicate a crcValid input byte
        inByte: in STD_LOGIC_VECTOR (7 downto 0);		-- Input byte
        crcValid: out STD_LOGIC;						-- Indicates crcValid CRC.  Active HIGH
        crcValue: out STD_LOGIC_VECTOR (31 downto 0)	-- CRC output
    );
end component;

-- buffer to store target MAC as we receive it
signal targetMAC: STD_LOGIC_VECTOR (47 downto 0);
signal nextTargetMAC: STD_LOGIC_VECTOR (47 downto 0);

-- state declarations
type STATETYPE is (stIdle, stLowNybbleRXClkLowTime, stLowNybbleRXClkHighTime, stHiNybbleRXClkLowTime, 
			stHiNybbleRXClkHighTime, stInvalidFrame, CHKCRC);

signal presState: STATETYPE;
signal nextState: STATETYPE;

signal rstCnt: STD_LOGIC;								-- signal to reset the address counter
signal incCnt: STD_LOGIC;								-- signal to increment the address counter
signal cnt: STD_LOGIC_VECTOR (3 downto 0);				-- byte counter for the header

-- buffer to hold the nybbles of each byte as they are received from the PHY
signal nextFrameData: STD_LOGIC_VECTOR (7 downto 0);	
signal frameDataSig: STD_LOGIC_VECTOR (7 downto 0);		-- internal signal that gets mapped to the frameData output

-- buffers for the asynchronous inputs from the PHY to avoid lockups
signal RX_DATALatch: STD_LOGIC_VECTOR (3 downto 0);
signal RX_DVLatch: STD_LOGIC;
signal RX_CLKLatch: STD_LOGIC;

-- signals for the CRC generator
signal newByte: STD_LOGIC;								-- sends a byte to the CRC checker when asserted
signal CRCNewFrame: STD_LOGIC;							-- resets the CRC checker when asserted
signal CRC: STD_LOGIC_VECTOR (31 downto 0);				-- CRC value

begin

	-- instantiate the CRC generator component
	crcGenEthRec : crcGenerator port map (
    	clk => clk,
        rstn => rstn,
        newFrame => CRCNewFrame,
        newByte => newByte,
        inByte => frameDataSig,
        crcValid => open,
        crcValue => CRC
    );

	-- set the frame data output to frameDataSig to avoid treating the frameData output as a buffer
	frameData <= frameDataSig;

A:	process (rstn, clk)
	begin
		-- create the asynchronous active low reset
		if rstn = '0' then
			presState <= stIdle;
		-- main clocked process
		elsif clk'EVENT and clk = '1' then
			presState <= nextState;
			-- set targetMAC and frameData to their next values (defaults to keeping the old)
			targetMAC <= nextTargetMAC;
			frameDataSig <= nextFrameData;
			-- increment or reset the count synchronously when required to avoid race conditions
			if incCnt = '1' then
				cnt <= cnt + 1;
			elsif rstCnt = '1' then
				cnt <= (others => '0');
			end if;
		end if;
	end process;		-- end process A
	
-- main FSM process
B:	process (presState, RX_DVLatch, RX_DATALatch, RX_CLKLatch, cnt, frameDataSig, targetMAC, 
			CRC)
	begin
		-- signal defaults
		incCnt <= '0';
		rstCnt <= '0';
		newFrame <= '0';
		endFrame <= '0';
		frameValid <= '0';
		newByte <= '0';
		frameByte <= '0';
		-- default nextFrameData and frameDataSig to their current values
		nextFrameData <= frameDataSig;
		nextTargetMAC <= targetMAC;
		frameType <= '0';
		CRCNewFrame <= '0';
		
		case presState is
			when stIdle =>
				-- if receive data valid signal is high, start receiving the nybbles of data
				if RX_DVLatch = '1' then
					nextState <= stLowNybbleRXClkLowTime;
					-- reset the CRC
					CRCNewFrame <= '1';
				-- else, wait for new data to arrive
				else
					nextState <= stIdle;
					rstCnt <= '1';
				end if;
			
			when stLowNybbleRXClkLowTime =>
				-- latch the lower nybble of a byte on the rising edge of RX_CLK, as the
				-- lower nybble is received first by the PHY and given to us
				if RX_CLKLatch = '1' then
					nextState <= stLowNybbleRXClkHighTime;
					nextFrameData (3 downto 0) <= RX_DATALatch;
				-- wait for the rising edge of RX_CLK
				else 
					nextState <= stLowNybbleRXClkLowTime;
				end if;
	
			when stLowNybbleRXClkHighTime =>
				if RX_CLKLatch = '0' then
					-- if data valid is low then the whole frame has been received, and return to idle
					-- do this here to make sure the CRC has had enough time to be calculated, as it takes
					-- 8 clock cycles (or just under one half of the RX_CLK's clock cycle)
					if RX_DVLatch = '0' then
						nextState <= CHKCRC;
					-- do nothing on the falling edge or the high time of RX_CLK
					else
						nextState <= stHiNybbleRXClkLowTime;
					end if;
				else
					nextState <= stLowNybbleRXClkHighTime;
				end if;

			when stHiNybbleRXClkLowTime =>
				-- latch the higher nybble on the rising edge of RX_CLK
				if RX_CLKLatch = '1' then
					nextState <= stHiNybbleRXClkHighTime;
					nextFrameData (7 downto 4) <= RX_DATALatch;
				-- wait for the rising edge of RX_CLK
				else
					nextState <= stHiNybbleRXClkLowTime;
				end if;
			
			when stHiNybbleRXClkHighTime =>
				-- on the falling edge edge of RX_CLK, handle the received full byte
				-- of data appopriately, according to the counter
				if RX_CLKLatch = '0' then
					nextState <= stLowNybbleRXClkLowTime;
					case cnt is
						-- ignore the SFD, as at 10megabit operation the PHY sends the SFD
						-- first, followed by the ethernet frame
						when x"0" =>
							incCnt <= '1';
						-- get the target MAC address, MSB first (byte 5)
						-- remember to send the received frame to the CRC to check it (newByte)
						when x"1" =>
							nextTargetMAC (47 downto 40) <= frameDataSig;
							newByte <= '1';					-- frame headers
							incCnt <= '1';
						-- get byte 4 of the target MAC address
						when x"2" =>
							nextTargetMAC (39 downto 32) <= frameDataSig;
							incCnt <= '1';
							newByte <= '1';
						-- get byte 3 of the target MAC address
						when x"3" =>
							nextTargetMAC (31 downto 24) <= frameDataSig;
							newByte <= '1';
							incCnt <= '1';
						-- get byte 2 of the target MAC address
						when x"4" =>
							nextTargetMAC (23 downto 16) <= frameDataSig;
							incCnt <= '1';
							newByte <= '1';
						-- get byte 1 of the target MAC address
						when x"5" =>
							nextTargetMAC (15 downto 8) <= frameDataSig;
							incCnt <= '1';
							newByte <= '1';
						-- get byte 0 of the target MAC address
						when x"6" =>						
							nextTargetMAC (7 downto 0) <= frameDataSig;
							incCnt <= '1';
							newByte <= '1';
						-- start receiving the sender's MAC (ignored)
						-- check to see if the frame was meant for us or a broadcast
						-- if not, ignore
						when x"7" =>
							incCnt <= '1';
							newByte <= '1';
							if targetMAC /= DEVICE_MAC and targetMAC /= x"FFFFFFFFFFFF" then
								nextState <= stInvalidFrame;
							end if;
						-- receive and ignore the rest of the sender's MAC address
						-- (still send all the bytes to the CRC)
						when x"8" | x"9" | x"A" | x"B" | x"C" =>
							incCnt <= '1';
							newByte <= '1';
						-- get the ethernet type code
						-- the first byte should be x"08"
						when x"D" =>
							incCnt <= '1';
							newByte <= '1';
							if frameDataSig /= 8 then
								nextState <= stInvalidFrame;
							end if;							
						-- get the second byte of the ethernet type field...
						-- should be 00 for and IP datargam or 06 for an ARP message
						-- ignore everything else, and set frameType accordingly 
						-- (1 for IP, 0 for ARP)
						when x"E" =>
							incCnt <= '1';
							newByte <= '1';
							if frameDataSig = 0 then
								frameType <= '1';
								newFrame <= '1';
							elsif frameDataSig = 6 then
								frameType <= '0';
								newFrame <= '1';
							else 
								nextState <= stInvalidFrame;
							end if;
						-- receive the rest of the data in the frame
						-- (the CRC will be sent to the next layers as well, but they
						-- should ignore the extra 4 bytes)
						when x"F" =>
							incCnt <= '0';
							frameByte <= '1';
							newByte <= '1';

						when others =>
					end case;
				-- else do nothing on the RX_CLK high time
				else
					nextState <= stHiNybbleRXClkHighTime;
				end if;
			
			when stInvalidFrame =>
				-- if for some reason the frame is invalid, go here and wait for
				-- the frame to finish transmitting (RX_DV going low)
				if RX_DVLatch = '0' then
					nextState <= stIdle;
				else
					nextState <= stInvalidFrame;
				end if;
				
			when CHKCRC =>
				nextState <= stIdle;
				-- reset the address counter for a new frame
				rstCnt <= '1';
				-- inform the next layers that we have finished receiving the frame
				endFrame <= '1';
				-- check too see if the irc is valid
				-- if not, the next layers will ignore the frame
				if CRC = 0 then
					frameValid <= '1';
				end if;

			when others =>
		end case;
	end process;		-- end process B
	
	-- process to latch the aysnchronous inputs from the PHY device to avoid lockups
	-- caused by violating timings
C:	process (clk, rstn)
	begin
		if rstn = '0' then
			RX_DATALatch <= "0000";
			RX_DVLatch <= '0';
			RX_CLKLatch <= '0';
		elsif clk'event and clk = '1' then
			RX_DATALatch <= RX_DATA;
			RX_DVLatch <= RX_DV;
			RX_CLKLatch <= RX_CLK;
		end if;
	end process;		-- end process C
end Ethernet_arch;
