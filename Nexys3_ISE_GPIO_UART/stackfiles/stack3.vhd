-------------------------------------------------------------------------------
-- stack3.vhd
--
-- Author(s):     Ashley Partis and Jorgen Peddersen
-- Created:       Jan 2001
-- Last Modified: Feb 2001
-- 
-- Top level for the TCP/IP stack.  Includes a RAM arbitrater to multiplex
-- usage of the RAM by the different levels.  Each level's priority of access
-- to the RAM is governed by the order of the if statement.  Any new level or
-- process that uses the RAM must be added to the arbitrater.
--
-------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;

entity stack is
    port (
        clk: in STD_LOGIC;								-- 50MHz clock from XSV board
        rstn: in STD_LOGIC;								-- asynchronous active low reset
        rxdata: in STD_LOGIC_VECTOR (3 downto 0);		-- 4 bit data receive line from the PHY
        rx_clk: in STD_LOGIC;							-- receive clock line from the PHY
        rx_dv: in STD_LOGIC;							-- receive data valid line from the PHY
        tx_clk: in STD_LOGIC;							-- transmit clock line from the PHY
        txdata: buffer STD_LOGIC_VECTOR (3 downto 0);	-- 4 bit data send line to the PHY
        tx_en: out STD_LOGIC;							-- transmit data enable line to the PHY
        tx_er: out STD_LOGIC;							-- transmit error line to the PHY
        mdc: out STD_LOGIC;								-- MII clock line
        mdio: out STD_LOGIC;							-- MII data I/O line
        trste: out STD_LOGIC;							-- line to tri-state the PHY outputs 
        lcen: out STD_LOGIC;							-- chip enable to the left bank of RAM
        loen: out STD_LOGIC;							-- output enable to the left bank of RAM
        lwen: out STD_LOGIC;							-- write enable to the left bank of RAM
        bar: out STD_LOGIC_VECTOR (9 downto 2);			-- top 8 bar graph LEDs
        ldata: inout STD_LOGIC_VECTOR (15 downto 0);	-- data lines from the left bank of RAM
        laddr: out STD_LOGIC_VECTOR (18 downto 0);		-- address lines from the left bank of RAM
        ppdata: in STD_LOGIC_VECTOR (7 downto 0);		-- parallel port data lines
        ppstatus: out STD_LOGIC_VECTOR (6 downto 3)		-- parallel port status lines
    );
end stack;

architecture stack_arch of stack is

-- component declarations
component ethernet is
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
end component;

component ethernetSnd is
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
end component;

component ARP is
    port (
		clk: in STD_LOGIC;								-- clock signal
		rstn: in STD_LOGIC;								-- asynchronous active low reset
		newFrame: in STD_LOGIC;							-- from ethernet layer indicates data arrival
		frameType: in STD_LOGIC;						-- '0' for an ARP message
		newFrameByte: in STD_LOGIC;						-- indicates a new byte in the stream
		frameData: in STD_LOGIC_VECTOR (7 downto 0);	-- the stream data
		endFrame: in STD_LOGIC;							-- asserted at the end of a frame
		frameValid: in STD_LOGIC; 						-- indicates validity while endFrame is asserted
		ARPSendAvail: in STD_LOGIC;						-- ARP sender asserts this when the reply is transmitted
		requestIP: in STD_LOGIC_VECTOR (31 downto 0);	-- ARP sender can request MACs for this address
		genARPRep: out STD_LOGIC;						-- tell ARP sender to generate a reply
		genARPIP: out STD_LOGIC_VECTOR (31 downto 0);	-- destination IP for generated reply
		lookupMAC: out STD_LOGIC_VECTOR (47 downto 0);	-- if valid, MAC for requested IP
		validEntry: out STD_LOGIC						-- indicates if requestIP is in table
    );
end component;

component ARPSnd is
    port (
        clk: in STD_LOGIC;								-- clock
        rstn: in STD_LOGIC;								-- aysnchronous active low rese
        complete: in STD_LOGIC;							-- RAM complete signal
        frameSent: in STD_LOGIC;						-- input from the PHY that it's processed our frame
        sendFrame: in STD_LOGIC;						-- send an ethernet frame - from IP layer
        frameLen: in STD_LOGIC_VECTOR (10 downto 0);	-- input from IP giving frame length
        targetIP: in STD_LOGIC_VECTOR (31 downto 0);	-- destination IP from the internet layer
        ARPEntryValid: in STD_LOGIC;					-- input from ARP indicating that it contains the requested IP
        genARPReply: in STD_LOGIC;						-- input from ARP requesting an ARP reply
        genARPIP: in STD_LOGIC_VECTOR (31 downto 0);	-- input from ARP saying which IP to send a reply to
        lookupMAC: in STD_LOGIC_VECTOR (47 downto 0);	-- input from ARP giving a requested MAC
        lookupIP: out STD_LOGIC_VECTOR (31 downto 0);	-- output to ARP requesting an IP to be looked up in the table
        sendingReply: out STD_LOGIC;					-- output to ARP to tell it's sending the ARP reply
        targetMAC: out STD_LOGIC_VECTOR (47 downto 0);	-- destination MAC for the physical layer
        genFrame: out STD_LOGIC;						-- tell the ethernet layer (PHY) to send a frame
        frameType: out STD_LOGIC;						-- tell the PHY to send an ARP frame or normal IP datagram
        frameSize: out STD_LOGIC_VECTOR (10 downto 0);	-- tell the PHY what size the frame size is
        idle: out STD_LOGIC;							-- idle signal
        sendingFrame: out STD_LOGIC; 					-- tell the IP layer that we're sending their data
        wrRAM: out STD_LOGIC;							-- write RAM signal to the RAM
        wrData: buffer STD_LOGIC_VECTOR (7 downto 0);	-- write data bus to the RAM
        wrAddr: out STD_LOGIC_VECTOR (18 downto 0)		-- write address bus to the RAM
    );
end component;

component internet is
    port (
		clk: in STD_LOGIC;								-- clock
		rstn: in STD_LOGIC;								-- asynchronouse active low reset
		complete: in STD_LOGIC;							-- control signal from ram arbitrator
		newFrame: in STD_LOGIC;							-- new frame received from the layer below
		frameType: in STD_LOGIC;						-- frame type = '1' for IP
		newFrameByte: in STD_LOGIC;						-- signals a new byte in the stream
		frameData: in STD_LOGIC_VECTOR (7 downto 0);	-- data is streamed in here
		endFrame: in STD_LOGIC;							-- signals the end of a frame
		frameValid: in STD_LOGIC;						-- determines validity of frame when endFrame is high
		newDatagram: out STD_LOGIC;						-- an IP datagram has been fully received
		bufferSelect: out STD_LOGIC;					-- indicates location of data in RAM, '0' = 10000, '1' = 20000
		datagramSize: out STD_LOGIC_VECTOR (15 downto 0);	-- size of the datagram received
		protocol: out STD_LOGIC_VECTOR (7 downto 0);		-- protocol type of datagram
		sourceIP: out STD_LOGIC_VECTOR (31 downto 0);		-- lets upper protocol know the source IP
		wrRAM: out STD_LOGIC;								-- signal to write to the RAM
		wrData: out STD_LOGIC_VECTOR (7 downto 0);			-- data to write to the RAM
		wrAddr: out STD_LOGIC_VECTOR (18 downto 0);			-- address lines to the RAM for writing
		timeLED0: out STD_LOGIC;							-- indicates if buffer 0 is busy
		timeLED1: out STD_LOGIC								-- indicates if buffer 1 is busy
	);
end component;

component InternetSnd is
    port (
        clk: in STD_LOGIC;									-- clock
        rstn: in STD_LOGIC;									-- active low asynchronous reset
        frameSent: in STD_LOGIC;							-- indicates the ethernet has sent a frame
        sendDatagram: in STD_LOGIC;							-- signal to send a datagram message
        datagramSize: in STD_LOGIC_VECTOR (15 downto 0);	-- size of datagram to transmit
        destinationIP: in STD_LOGIC_VECTOR (31 downto 0);	-- IP to transmit message to
        addressOffset: in STD_LOGIC_VECTOR (2 downto 0);	-- Indicates location in RAM of datagram
        protocol: in STD_LOGIC_VECTOR (7 downto 0);			-- protocol of the datagram to be sent
        complete: in STD_LOGIC;								-- complete signal from the RAM operation
        rdData: in STD_LOGIC_VECTOR (7 downto 0);			-- read data from RAM
        rdRAM: out STD_LOGIC;								-- read signal for RAM
        rdAddr: out STD_LOGIC_VECTOR (18 downto 0);			-- read address for RAM
        wrRAM: out STD_LOGIC;								-- write signal for RAM
        wrData: buffer STD_LOGIC_VECTOR (7 downto 0);		-- write data for RAM
        wrAddr: out STD_LOGIC_VECTOR (18 downto 0);			-- write address for RAM
        sendFrame: out STD_LOGIC;							-- signal to get ethernet to send frame
        datagramSent: out STD_LOGIC;						-- tells higher protocol when the datagram was sent
        frameSize: out STD_LOGIC_VECTOR (10 downto 0);		-- tells the ethernet layer how long the frame is
        ARPIP: out STD_LOGIC_VECTOR (31 downto 0)			-- IP that the ARP layer must look up
    );
end component;

component udp is
    port (
		clk: in STD_LOGIC;									-- clock
		rstn: in STD_LOGIC;									-- asychronous active low reset
		protocol: in STD_LOGIC_VECTOR (7 downto 0);			-- protocol of the datagram from the internet layer
		newDatagram: in STD_LOGIC;							-- new datagram signal from the internet layer
		sourceIP: in STD_LOGIC_VECTOR (31 downto 0);		-- IP address of the sender
		IPbuffer: in STD_LOGIC;								-- which buffer the IP address was stored in
		complete: in STD_LOGIC;								-- RAM read / write complete signal
		rdData: in STD_LOGIC_VECTOR (7 downto 0);			-- read data bus to the RAM
		rdRAM: out STD_LOGIC;								-- read RAM signal
		rdAddr: out STD_LOGIC_VECTOR (18 downto 0);			-- read RAM address bua
		wrRAM: out STD_LOGIC;								-- write RAM signal
		wrData: out STD_LOGIC_VECTOR (7 downto 0);			-- write data bus to the RAM
		wrAddr: out STD_LOGIC_VECTOR (18 downto 0);			-- write address bus to the RAM
		sourceIPOut: out STD_LOGIC_VECTOR (31 downto 0)		-- IP address of the sender
    );
end component;

component icmp is
    port (
        clk: in STD_LOGIC;										-- clock
        rstn: in STD_LOGIC;										-- asynchronous active low reset
        newDatagram: in STD_LOGIC;								-- asserted when a new datagram arrive
        datagramSize: in STD_LOGIC_VECTOR (15 downto 0);		-- size of the arrived datagram
        bufferSelect: in STD_LOGIC;								-- informs which IP buffer the data is in
   		protocolIn: in STD_LOGIC_VECTOR (7 downto 0);			-- protocol type of the datagram
		sourceIP: in STD_LOGIC_VECTOR (31 downto 0);			-- IP address that sent the message
        complete: in STD_LOGIC;									-- asserted when then RAM operation is complete
        rdData: in STD_LOGIC_VECTOR (7 downto 0);				-- read data bus from the RAM
        rdRAM: out STD_LOGIC;									-- asserted to tell the RAM to read
        rdAddr: out STD_LOGIC_VECTOR (18 downto 0);				-- read address bus to the RAM
        wrRAM: out STD_LOGIC;									-- asserted to tell the RAM to write
        wrData: buffer STD_LOGIC_VECTOR (7 downto 0);			-- write data bus to the RAM
        wrAddr: out STD_LOGIC_VECTOR (18 downto 0);				-- write address bus to the RAM
        sendDatagramSize: out STD_LOGIC_VECTOR (15 downto 0);	-- size of the ping to reply to
        sendDatagram: out STD_LOGIC;							-- tells the IP layer to send a datagram
        destinationIP: out STD_LOGIC_VECTOR (31 downto 0);		-- target IP of the datagram
        addressOffset: out STD_LOGIC_VECTOR (2 downto 0);		-- tells the IP layer which buffer the data is in
        protocolOut: out STD_LOGIC_VECTOR (7 downto 0)			-- tells the IP layer which protocol it is
    );
end component;

component sraminterfacewithpport is
    port (
        CLK: in STD_LOGIC;								-- Clock signal.
        Resetn: in STD_LOGIC;							-- Asynchronous reset
        doRead: in STD_LOGIC;							-- Currently unused but may be used in future.
        doWrite: in STD_LOGIC;							-- Set to perform a write.
        readAddr: in STD_LOGIC_VECTOR (18 downto 0);	-- Address to read from (user-side).
        writeAddr: in STD_LOGIC_VECTOR (18 downto 0);	-- Address to write to (user-side).
        readData: out STD_LOGIC_VECTOR (15 downto 0);	-- Data read (user-side).
        writeData: in STD_LOGIC_VECTOR (15 downto 0);	-- Data to write (user-side).
        canRead: out STD_LOGIC;							-- Is '1' when a read can be performed.
        canWrite: out STD_LOGIC;						-- Is '1' when a write can be performed.
        CELeftn: out STD_LOGIC;							-- CEn signal to left SRAM bank.
        OELeftn: out STD_LOGIC;							-- OEn signal to left SRAM bank.
        WELeftn: out STD_LOGIC;							-- WEn signal to left SRAM bank.
        SRAMLeftAddr: out STD_LOGIC_VECTOR (18 downto 0);	-- Address bus to left SRAM bank.
        SRAMLeftData: inout STD_LOGIC_VECTOR (15 downto 0);	-- Data bus to left SRAM bank.
		ppdata : in STD_LOGIC_VECTOR(7 downto 0);		-- Parallel port data lines (for PC SRAM access).
		ppstatus : out STD_LOGIC_VECTOR(6 downto 3)		-- Parallel port status lines (for PC SRAM acces).
    );
end component;

-- clock buffer for the clock input pads on the Xilinx FPGA
-- needed to force foundation to recognise TX_CLK and RX_CLK as clocks,
-- rather than inputs
component bufg
	port (
		I: in STD_LOGIC;
		O: out STD_LOGIC
	);
end component;

-- state definitions for the RAM arbitrater
type STATETYPE is (stIdle, stServicingNet, stServicingTrans, stServicingNetSnd, stServicingEthSnd,
			stServicingARPSnd, stServicingUDP);
signal presstate : STATETYPE;
signal nextstate : STATETYPE;

-- signals from the ethernet receive layer to the internet and ARP layers
signal newFrame: STD_LOGIC;
signal frameTypeRec: STD_LOGIC;
signal newFrameByte: STD_LOGIC;
signal frameData: STD_LOGIC_VECTOR (7 downto 0);
signal endFrame: STD_LOGIC;
signal frameValid: STD_LOGIC;

-- signals from the ARP layer to the ARPSnd layer
signal ARPSendAvail: STD_LOGIC;
signal genARPRep: STD_LOGIC;
signal genARPIP: STD_LOGIC_VECTOR (31 downto 0);
signal requestIP: STD_LOGIC_VECTOR (31 downto 0);
signal lookupMAC: STD_LOGIC_VECTOR (47 downto 0);
signal validEntry: STD_LOGIC;

-- signals from the IP layer to the ICMP and UDP layers
signal newDatagram: STD_LOGIC;
signal datagramSize: STD_LOGIC_VECTOR (15 downto 0);
signal bufferSelect: STD_LOGIC;
signal sourceIP: STD_LOGIC_VECTOR(31 downto 0);
signal protocolRec: STD_LOGIC_VECTOR (7 downto 0);

-- signals from the ICMP layer to the internet send layer
signal sendDatagram: STD_LOGIC;
signal sendDatagramSize: STD_LOGIC_VECTOR (15 downto 0);
signal destinationIP: STD_LOGIC_VECTOR(31 downto 0);
signal protocolSend: STD_LOGIC_VECTOR (7 downto 0);
signal addressOffset: STD_LOGIC_VECTOR (2 downto 0);

-- signals from the internet send layer to the ARP send layer
signal sendFrame: STD_LOGIC;
signal frameSize: STD_LOGIC_VECTOR (10 downto 0);
signal ARPIP: STD_LOGIC_VECTOR (31 downto 0);
signal frameSent: STD_LOGIC;

-- signals from the ARP send layer to the ethernet send layer
signal frameLenARP: STD_LOGIC_VECTOR (10 downto 0);
signal frameTypeSend: STD_LOGIC;
signal sendFrameARP: STD_LOGIC;
signal destinationMAC: STD_LOGIC_VECTOR (47 downto 0);
signal frameSentEth: STD_LOGIC;

-- signals for the RAM
signal rdRAM: STD_LOGIC;
signal rdData: STD_LOGIC_VECTOR (7 downto 0);
signal rdAddr: STD_LOGIC_VECTOR (18 downto 0);
signal wrData: STD_LOGIC_VECTOR (7 downto 0);
signal wrAddr: STD_LOGIC_VECTOR (18 downto 0);
signal wrRAM: STD_LOGIC;
signal canWrite : STD_LOGIC;
signal waste: STD_LOGIC_VECTOR (7 downto 0);

-- signals from the RAM to other layers
signal wrRAMNet: STD_LOGIC;
signal wrDataNet: STD_LOGIC_VECTOR (7 downto 0);
signal wrAddrNet: STD_LOGIC_VECTOR (18 downto 0);
signal RAMCompleteNet : STD_LOGIC;
signal rdRAMTrans: STD_LOGIC;
signal rdAddrTrans: STD_LOGIC_VECTOR (18 downto 0);
signal wrRAMTrans: STD_LOGIC;
signal wrDataTrans: STD_LOGIC_VECTOR (7 downto 0);
signal wrAddrTrans: STD_LOGIC_VECTOR (18 downto 0);
signal RAMCompleteTrans : STD_LOGIC;
signal rdRAMNetSnd: STD_LOGIC;
signal rdAddrNetSnd: STD_LOGIC_VECTOR (18 downto 0);
signal wrRAMNetSnd: STD_LOGIC;
signal wrDataNetSnd: STD_LOGIC_VECTOR (7 downto 0);
signal wrAddrNetSnd: STD_LOGIC_VECTOR (18 downto 0);
signal RAMCompleteNetSnd: STD_LOGIC;
signal rdRAMEthSnd: STD_LOGIC;
signal rdAddrEthSnd: STD_LOGIC_VECTOR (18 downto 0);
signal RAMCompleteEthSnd: STD_LOGIC;
signal wrRAMARPSnd: STD_LOGIC;
signal wrDataARPSnd: STD_LOGIC_VECTOR (7 downto 0);
signal wrAddrARPSnd: STD_LOGIC_VECTOR (18 downto 0);
signal RAMCompleteARPSnd: STD_LOGIC;
signal rdRAMUDP: STD_LOGIC;
signal rdAddrUDP: STD_LOGIC_VECTOR (18 downto 0);
signal wrRAMUDP: STD_LOGIC;
signal wrDataUDP: STD_LOGIC_VECTOR (7 downto 0);
signal wrAddrUDP: STD_LOGIC_VECTOR (18 downto 0);
signal RAMCompleteUDP: STD_LOGIC;

-- signals for the clock buffers for rx_clk and tx_clk
signal rx_clk_buf: STD_LOGIC;
signal tx_clk_buf: STD_LOGIC;

begin

	-- instantiation of the ethernet receiver component
	MAS : ethernet port map (
		clk => clk,
		rstn => rstn,
		RX_DATA => rxdata,
		RX_DV => rx_dv,
		RX_CLK => rx_clk_buf,
		frameType => frameTypeRec,
		frameByte => newFrameByte,
		frameData => frameData,
		newFrame => newframe,
		endFrame => endFrame,
		frameValid => frameValid
	);
	
	-- instantiantion of the ethernet sender component 
	MASSnd : ethernetSnd port map (
        clk => clk,
        rstn => rstn,
        complete => RAMCompleteEthSnd,
        rdData => rdData,
        newFrame => sendFrameARP,
        frameSize => frameLenARP,
        destinationMAC => destinationMAC,
        frameType => frameTypeSend,
        TX_CLK => tx_clk_buf,
        TX_EN => tx_en,
        TX_DATA => txdata,
        rdRAM => rdRAMEthSnd,
        rdAddr => rdAddrEthSnd,
        frameSent => frameSentEth
    );

	-- instantiantion of the ARP component 
	ARPTable : ARP port map (
		clk => clk,
		rstn => rstn,
		newFrame => newFrame,
		frameType => frameTypeREC,
		newFrameByte => newFrameByte,
		frameData => frameData,
		endFrame => endFrame,
		frameValid => frameValid,
		ARPSendAvail => ARPSendAvail,
		requestIP => requestIP,
		genARPRep => genARPRep,
		genARPIP => genARPIP,
		lookupMAC => lookupMAC,
		validEntry => validEntry
    );

	-- instantiantion of the ARP request / reply sender component 
	ARPSender : ARPSnd port map (
        clk => clk,
        rstn => rstn,
        complete => RAMCompleteARPSnd,
        frameSent => frameSentEth,
        sendFrame => sendFrame,
        frameLen => frameSize,
        targetIP => ARPIP,
        ARPEntryValid => validEntry,
        genARPReply => genARPRep,
        genARPIP => genARPIP,
        lookupMAC => lookupMAC,
        lookupIP => requestIP,
        sendingReply => ARPSendAvail,
        targetMAC => destinationMAC,
        genFrame => sendFrameARP,
        frameType => frameTypeSend,
        frameSize => frameLenARP,
        idle => open,
        sendingFrame => frameSent,
        wrRAM => wrRAMARPSnd,
        wrData => wrDataARPSnd,
        wrAddr => wrAddrARPSnd
    );
    
	-- instantiantion of the internet datagram receiver component 
	networkLayer : internet port map (
		clk => clk,
		rstn => rstn,
		complete => RAMCompleteNet,
		newFrame => newFrame,
		frameType => frameTypeRec,
		newFrameByte => newFrameByte,
		frameData => frameData,
		endFrame => endFrame,
		frameValid => frameValid,
		newDatagram => newDatagram,
		bufferSelect => bufferSelect,
		datagramSize => datagramSize,
		protocol => protocolRec,
		sourceIP => sourceIP,
		wrRAM => wrRAMNet,
		wrData => wrDataNet,
		wrAddr => wrAddrNet,
		timeLED0 => bar(2),
		timeLED1 => bar(3)
    );

	-- instantiantion of the internet datagram sender component 
	networkLayerSend: InternetSnd port map(
        clk => clk,
        rstn => rstn,
        frameSent => frameSent,
        sendDatagram => sendDatagram,
        datagramSize => sendDatagramSize,
        destinationIP => destinationIP,
        addressOffset => addressOffset,
        protocol => protocolSend,
        complete => RAMCompleteNetSnd,
        rdData => rdData,
        rdRAM => rdRAMNetSnd,
        rdAddr => rdAddrNetSnd,
        wrRAM => wrRAMNetSnd,
        wrData => wrDataNetSnd,
        wrAddr => wrAddrNetSnd,
        sendFrame => sendFrame,
        datagramSent => open,
        frameSize => frameSize,
        ARPIP => ARPIP
    );
    
	-- instantiantion of the UDP receiver component 
	UDPtransportLayer: udp port map (
		clk => clk,
		rstn => rstn,
		protocol => protocolRec,
		newDatagram => newDatagram,
		sourceIP => sourceIP,
		IPbuffer => bufferSelect,
		complete => RAMCompleteUDP,
		rdData => rdData,
		rdRAM => rdRAMUDP,
		rdAddr => rdAddrUDP,
		wrRAM => wrRAMUDP,
		wrData => wrDataUDP,
		wrAddr => wrAddrUDP,
		sourceIPOut => open
    );
    
    
	-- instantiantion of the ICMP protocol component
	ICMPtransportLayer: ICMP port map (
        clk => clk,
        rstn => rstn,
        newDatagram => newDatagram,
        datagramSize => datagramSize,
        bufferSelect => bufferSelect,
   		protocolIn => protocolRec,
		sourceIP => sourceIP,
        complete => RAMCompleteTrans,
        rdData => rdData,
        rdRAM => rdRAMTrans,
        rdAddr => rdAddrTrans,
        wrRAM => wrRAMTrans,
        wrData => wrDataTrans,
        wrAddr => wrAddrTrans,
        sendDatagramSize => sendDatagramSize,
        sendDatagram => sendDatagram,
        destinationIP => destinationIP,
        addressOffset => addressOffset,
        protocolOut => protocolSend
    );

	-- instantiantion of the SRAM component
	SRAMInterface : sraminterfacewithpport port map (
        clk => clk,
        Resetn => rstn,
        doRead => rdRAM,
        doWrite => wrRAM,
        readAddr => rdAddr,
        writeAddr => wrAddr,
        readData (15 downto 8) => open,
        readData (7 downto 0) => rdData,
        writeData (15 downto 8) => waste,
        writeData (7 downto 0) => wrData,
        canRead => open,
        canWrite => canWrite,
        CELeftn => lcen,
        OELeftn => loen,
        WELeftn => lwen,
        SRAMLeftAddr => laddr,
        SRAMLeftData => ldata,
        ppdata => ppdata,
        ppstatus => ppstatus
    );
    
	-- clock buffer for RX_CLOCK
	rx_clkBuff : bufg port map (
		I => rx_clk,
		O => rx_clk_buf
	);

	-- clock buffer for TX_CLOCK
	tx_clkBuff : bufg port map (
		I => tx_clk,
		O => tx_clk_buf
	);

	-- hardwire TX_ER, mdc, mdio and trste to low - none of these are used
	tx_er <= '0';
	mdc <= '0';
	mdio <= '0';
	trste <= '0';

	-- waste signal - useless
	waste <= (others => '0');


	-- RAM arbitration for the whole project
	-- main clocked process
	process(clk,rstn)
	begin
		if rstn = '0' then
			presState <= stIdle;
		elsif clk'event and clk = '1' then
			presState <= nextState;
		end if;
	end process;
			
	-- FSM process
	process (presState, wrRAMNet, wrDataNet, wrAddrNet, rdRAMTrans, rdAddrTrans, wrRAMTrans, 
			wrDataTrans, canWrite, wrAddrTrans, rdRAMNetSnd, rdAddrNetSnd, wrRAMNetSnd, wrDataNetSnd, 
			wrAddrNetSnd, wrRAMARPSnd, wrRAMARPSnd, wrDataARPSnd, wrAddrARPSnd, rdAddrEthSnd, rdRAMEthSnd,
			rdRAMUDP, rdAddrUDP, wrRAMUDP, wrDataUDP, wrAddrUDP)
	begin
		-- if we can write or read, then allow whoever requests it and multiplex the RAM lines
		if presState = stIdle or canWrite = '1' then
			-- giving ethernet send priority...
			if rdRAMEthSnd = '1' then
				nextState <= stServicingEthSnd;
				wrRAM <= '0';
				rdRAM <= rdRAMEthSnd;
				wrData <= (others => '0');
				wrAddr <= (others => '0');
				rdAddr <= rdAddrEthSnd;
			elsif wrRAMARPSnd = '1' then
				nextState <= stServicingARPSnd;
				wrRAM <= wrRAMARPSnd;
				rdRAM <= '0';
				wrData <= wrDataARPSnd;
				wrAddr <= wrAddrARPSnd;
				rdAddr <= (others => '0');
			elsif wrRAMNet = '1' then
				nextState <= stServicingNet;
				wrRAM <= wrRAMNet;
				rdRAM <= '0';
				wrData <= wrDataNet;
				wrAddr <= wrAddrNet;
				rdAddr <= (others => '0');
			elsif wrRAMTrans = '1' or rdRAMTrans = '1' then
				nextState <= stServicingTrans;			
				wrRAM <= wrRAMTrans;
				rdRAM <= rdRAMTrans;
				wrData <= wrDataTrans;
				wrAddr <= wrAddrTrans;
				rdAddr <= rdAddrTrans;
			elsif wrRAMNetSnd = '1' or rdRAMNetSnd = '1' then
				nextState <= stServicingNetSnd;
				wrRAM <= wrRAMNetSnd;
				rdRAM <= rdRAMNetSnd;
				wrData <= wrDataNetSnd;
				wrAddr <= wrAddrNetSnd;
				rdAddr <= rdAddrNetSnd;
			elsif wrRAMUDP = '1' or rdRAMUDP = '1' then
				nextState <= stServicingUDP;
				wrRAM <= wrRAMUDP;
				rdRAM <= rdRAMUDP;
				wrData <= wrDataUDP;
				wrAddr <= wrAddrUDP;
				rdAddr <= rdAddrUDP;
			else
				nextState <= stIdle; 
				wrRAM <= '0';
				rdRam <= '0';
				wrData <= (others => '0');
				wrAddr <= (others => '0');
				rdAddr <= (others => '0');
			end if;			
		else
			nextState <= presState; 
			wrRAM <= '0';
			rdRAM <= '0';
			wrData <= (others => '0');
			wrAddr <= (others => '0');
			rdAddr <= (others => '0');			
		end if;

		-- connect the RAM complete signal to each state which requested it when needed
		case presState is
			when stIdle =>
				RAMcompleteNet <= '0';
				RAMcompleteTrans <= '0';
				RAMcompleteNetSnd <= '0';
				RAMcompleteEthSnd <= '0';
				RAMcompleteARPSnd <= '0';
				RAMcompleteUDP <= '0';
			when stServicingNet =>
				RAMcompleteNet <= canWrite;
				RAMcompleteTrans <= '0';
				RAMcompleteNetSnd <= '0';
				RAMcompleteEthSnd <= '0';
				RAMcompleteARPSnd <= '0';
				RAMcompleteUDP <= '0';
			when stServicingTrans =>
				RAMcompleteNet <= '0';
				RAMcompleteTrans <= canWrite;
				RAMcompleteNetSnd <= '0';
				RAMcompleteEthSnd <= '0';
				RAMcompleteARPSnd <= '0';
				RAMcompleteUDP <= '0';
			when stServicingNetSnd =>
				RAMcompleteNet <= '0';
				RAMcompleteTrans <= '0';
				RAMcompleteNetSnd <= canwrite;
				RAMcompleteEthSnd <= '0';
				RAMcompleteARPSnd <= '0';
				RAMcompleteUDP <= '0';
			when stServicingEthSnd =>
				RAMcompleteNet <= '0';
				RAMcompleteTrans <= '0';
				RAMcompleteNetSnd <= '0';
				RAMcompleteEthSnd <= canWrite;
				RAMcompleteARPSnd <= '0';
				RAMcompleteUDP <= '0';
			when stServicingARPSnd =>
				RAMcompleteNet <= '0';
				RAMcompleteTrans <= '0';
				RAMcompleteNetSnd <= '0';
				RAMcompleteEthSnd <= '0';
				RAMcompleteARPSnd <= canWrite;
				RAMcompleteUDP <= '0';
			when stServicingUDP =>
				RAMcompleteNet <= '0';
				RAMcompleteTrans <= '0';
				RAMcompleteNetSnd <= '0';
				RAMcompleteEthSnd <= '0';
				RAMcompleteARPSnd <= '0';
				RAMcompleteUDP <= canWrite;
			when others =>
				RAMcompleteNet <= '0';
				RAMcompleteTrans <= '0';
				RAMcompleteNetSnd <= '0';
				RAMcompleteEthSnd <= '0';
				RAMcompleteARPSnd <= '0';
				RAMcompleteUDP <= '0';
		end case;	
	end process;							
end stack_arch;
