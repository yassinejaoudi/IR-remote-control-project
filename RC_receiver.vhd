-- RC_receiver
-- implement a data receiver for the DE2 remote control
--Venkataramani
--4th December 2018
--Approach-1
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity RC_receiver is
generic (
	-- number of clocks for the leader code_on signal (assume 50MHZ clock)
	LC_on_max				: integer := 450000
	);
port(
	-- outputs to the 8 7-segment displays. The remote control
	-- outputs 32 bits of binary data (each byte display as 
	-- 2 7-segment displays)
	HEX7					: out std_logic_vector(6 downto 0);
	HEX6					: out std_logic_vector(6 downto 0);
	HEX5					: out std_logic_vector(6 downto 0);
	HEX4					: out std_logic_vector(6 downto 0);
	HEX3					: out std_logic_vector(6 downto 0);
	HEX2					: out std_logic_vector(6 downto 0);
	HEX1					: out std_logic_vector(6 downto 0);
	HEX0					: out std_logic_vector(6 downto 0);
	
	LEDG 					: out std_logic_vector(7 downto 0);
	LEDR					: out std_logic_vector(17 downto 0);
	-- output to display when receiver is receiving data
	rd_data 				: out std_logic;
	-- clock, data input, and system reset
	clk 					: in std_logic;
	data_in 				: in std_logic;
	reset 					: in std_logic);
end RC_receiver;

architecture arc of RC_receiver is 
-- leader code off duration
-- lengths of symbols '1' and '0'
-- length of transition time (error)
constant LC_off_max			: integer := LC_on_max/2;
constant one_clocks			: integer := LC_on_max/4;
constant zero_clocks			: integer := LC_on_max/8;	
constant trans_max			: integer := LC_on_max/50; 
constant LC_off_repeat_max		: integer := LC_off_max/2; 

------------------------------------------------------------------
constant max_bits			    : integer := 32;
-- counter for measuring the duration of the leader code-on signal
signal reading_LC_on		    : std_logic := '0';
signal LC_on_counter		    : integer range 0 to LC_on_max+trans_max;
-- counter for measuring the duration of the leader code-off signal
signal reading_LC_off		    : std_logic := '0';
signal LC_off_counter		    : integer range 0 to LC_off_max+trans_max;
-- counter for measuring the duration of the data signal
signal reading_data		    : std_logic := '0';
signal clock_counter		    : integer range 0 to one_clocks+trans_max;
signal checking_data		    : std_logic := '0';
-- signal which determine the bit that is communicated
signal data_bit			    : std_logic := '0';

-- counter to keep track of the number of bits transmitted
signal data_counter		    : integer := 0;
-- signals for edge detection circuitry
signal data				    : std_logic;
signal data_follow 		    : std_logic;
signal pos_edge			    : std_logic;
-- shift register which holds the transmitted bits
signal shift_reg: std_logic_vector(max_bits-1 downto 0) := (others => '0'); 
signal data_reg : std_logic_vector(max_bits-1 downto 0) := (others => '0');
signal temp	    : std_logic_vector(max_bits-1 downto 0) := (others => '0');

-- state machine signals
type state_type is (init, read_LC_on, check_LC_on_count, read_LC_off, 
		check_LC_off_count, read_data, check_data);
signal state, nxt_state		: state_type;

-- The code is divided into different process: (i) LED process (ii) 7 Segment display (iii)State machine process
-- LED signals
signal command			: std_logic_vector(7 downto 0);
signal dt_rdy			: std_logic := '0'; -- Data ready
signal LG_reg			: std_logic_vector(7 downto 0); -- Green LEDs
signal LR_reg			: std_logic_vector(17 downto 0); -- Red LEDs 
-- 7 segment display circuitry
component hex_to_7_seg is 
port (
	seven_seg		: out std_logic_vector(6 downto 0);
	hex				: in std_logic_vector(3 downto 0));
end component; 

begin
	-- state machine processes 
	-- Defining clock
	state_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				state <= init;   -- Based on the assignment sheet
			else
				state <= nxt_state;
			end if;
		end if;
	end process state_proc;
	nxt_state_proc : process(state, pos_edge, data, LC_on_counter,LC_off_counter, clock_counter, data_counter)
	begin
		nxt_state <= state;-- Initialization of the various states 
		reading_LC_on <= '0';
		reading_LC_off <= '0';	
		reading_data <= '0';  
		checking_data <= '0'; 
		
	--- The entire state machine was developed based
	--- on the details given in the assignment 
	--- Nothing new was added
		case state is
			when init => 
				if(data = '0') then
					nxt_state <= read_LC_on;
				else
					nxt_state <= init;
				end if;
			when read_LC_on =>
				reading_LC_on <= '1';
				if(pos_edge = '1') then
					nxt_state <= check_LC_on_count;
				else
					nxt_state <= read_LC_on;
				end if;
			when check_LC_on_count =>
   if ((LC_on_counter < LC_on_max+trans_max) and    (LC_on_counter > LC_on_max-trans_max)) then
					nxt_state <= read_LC_off;
				else
					nxt_state <= init;
				end if;
			when read_LC_off =>
				reading_LC_off <= '1';
				if(data = '0') then
					nxt_state <= check_LC_off_count;
				else
					nxt_state <= read_LC_off;
				end if;
			when check_LC_off_count =>
if ((LC_off_counter < LC_off_max+trans_max) and (LC_off_counter > LC_off_max-trans_max)) then
					nxt_state <= read_data;
elsif ((LC_off_counter < LC_off_repeat_max+trans_max) and (LC_off_counter > LC_off_repeat_max-trans_max)) then
					nxt_state <= init;
				else
					nxt_state <= init;
				end if;
			when read_data =>
				reading_data <= '1';
				if(pos_edge = '1') then
					nxt_state <= check_data;
				else
					nxt_state <= read_data;
				end if;				
			when check_data =>
				checking_data <= '1';
				if(data_counter /= 31) then
					nxt_state <= read_data;
				else
					nxt_state <= init;
				end if;
				
			when others =>
				nxt_state <= init;
		end case;				
	end process nxt_state_proc;
	
	
	-- Pulse detection circuitry
	pos_edge <= data and data_follow;
	pos_edge_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				data <= '0';
				data_follow <= '0';
			else
				data <= data_in;
				data_follow <= not data;
			end if;
		end if;
	end process pos_edge_proc;	
	
	
	
	LC_on_counter_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if((reset = '0') or (LC_on_counter = LC_on_max+trans_max)) then
				LC_on_counter <= 0;
			elsif(reading_LC_on = '1') then
				LC_on_counter <= LC_on_counter + 1;
			else
				LC_on_counter <= 0;
			end if;
		end if;
	end process LC_on_counter_proc;	
	
	-- LC_off counter
	-- Based on the state machine
	-- Either reset or in the buffer mode (2% tolerance)
	LC_off_counter_proc : process(clk)
	begin
		if(rising_edge(clk)) then
if((reset = '0') or(LC_off_counter = LC_off_max+trans_max))   then
				LC_off_counter <= 0;
			elsif(reading_LC_off = '1') then
				LC_off_counter <= LC_off_counter + 1;
			else
				LC_off_counter <= 0;
			end if;
		end if;
	end process LC_off_counter_proc;	
		
	-- clock counter can be written as process :
	cc_proc : process(clk)
	begin
		if(rising_edge(clk)) then
if((reset = '0') or (clock_counter = one_clocks+trans_max) or checking_data = '1') then
				clock_counter <= 0;
			elsif(reading_data = '1') then
				clock_counter <= clock_counter + 1;
			else
				clock_counter <= 0;
			end if;
		end if;
	end process cc_proc;
	
	--To find the nature of the bit that is transmitted
	rd_data <= data_bit;	
	data_bit_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				data_bit <= '0';
			elsif(checking_data = '1') then
if((clock_counter < one_clocks+trans_max) and (clock_counter > one_clocks-trans_max)) then
						data_bit <= '1';	
elsif((clock_counter < zero_clocks+trans_max) and (clock_counter > zero_clocks-trans_max)) then
						data_bit <= '0';
					end if;	
			end if;
		end if;
	end process data_bit_proc;
	
-- This is the process for the data counter
	dc_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0' or data_counter = max_bits) then
				data_counter <= 0;
			elsif(checking_data = '1') then
				data_counter <= data_counter + 1;
			end if;
		end if;
	end process dc_proc;
	
	--This is the process for the working of shift register:
	shift_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				shift_reg <= (others => '0');
			elsif(clock_counter = 0 and data_counter /= 31) then
				shift_reg <= data_bit & shift_reg(31 downto 1);
 				--shift_reg(data_counter-1) <= data_bit;
			end if;
		end if;
	end process shift_proc;		
	
	
	--final check and store 32 bits data, data reg process
	dr_reg_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				data_reg <= (others => '0');
				temp <= (others => '0');
			elsif(data_counter = 32) then
		      data_reg <= shift_reg(1 downto 0) & shift_reg(31 downto 2);
			
				dt_rdy <= '1';						
			else
			   dt_rdy <= '0';		  
			end if;
		end if;
	end process dr_reg_proc;	
				
				
	-- 7 segment displays
	Seg0: hex_to_7_seg port map(HEX7,data_reg(31 downto 28)) ;
	Seg1: hex_to_7_seg port map(HEX6,data_reg(27 downto 24)) ;
	Seg2: hex_to_7_seg port map(HEX5,data_reg(23 downto 20)) ;
	Seg3: hex_to_7_seg port map(HEX4,data_reg(19 downto 16)) ;
	Seg4: hex_to_7_seg port map(HEX3,data_reg(15 downto 12)) ;
	Seg5: hex_to_7_seg port map(HEX2,data_reg(11 downto 8)) ;
	Seg6: hex_to_7_seg port map(HEX1,data_reg(7 downto 4)) ;
	Seg7: hex_to_7_seg port map(HEX0,data_reg(3 downto 0)) ;
	
	--- Task-2 Command Discrimination and Execution
	LEDG <= LG_reg;
	LEDR <= LR_reg;
	command <= data_reg(23 downto 16);
	
	task2_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				LR_reg <= (others => '0');
				LG_reg <= (others => '0');
			else
         if(dt_rdy = '1') then   --Data ready signal
			case command is
					--For implementing Power on and Off
		when x"12" => 
		     if(LG_reg(0) = '0' and LR_reg(0) = '0') then
					LG_reg(0) <= '1';
					LG_reg(7 downto 1) <= "0000000";
					LR_reg(17 downto 0) <= "000000000000000000";

			elsif(LG_reg(0) = '1' and LR_reg(0) = '0') then
					LR_reg(0) <= '1';
					LR_reg(17 downto 1) <= "00000000000000000";
					LG_reg(7 downto 0) <= "00000000";

				elsif(LG_reg(0) = '0' and LR_reg(0) = '1') then
					LG_reg(0) <= '1';
					LG_reg(7 downto 1) <= "0000000";
					LR_reg(17 downto 0) <= "000000000000000000";
						end if;
					--For ensuring that when channel 2 is ON Channel 7 is OFF and vice versa
			when x"02" =>						
				LR_reg(17 downto 0) <= "000000000000000100";			
			when x"07" => 
				LR_reg(17 downto 0) <= "000000000010000000";
					--Working of the mute button
			when x"0C" =>
						LR_reg(12) <= not LR_reg(12);
						LR_reg(11 downto 0) <= "000000000000";
						LR_reg(17 downto 13) <= "00000";
	--Volume up/down resetting it and trying to implement the repeat code.
			when x"1B" =>						
				LR_reg(17 downto 0) <= "000000010000000000";	  				when x"1F" => 
				LR_reg(17 downto 0) <= "000000100000000000";							
			when others =>
				LG_reg <= "00000000";
				LR_reg <= "000000000000000000";
			end case;				
			end if;
			end if;
		end if;
	end process task2_proc;	
end arc;
