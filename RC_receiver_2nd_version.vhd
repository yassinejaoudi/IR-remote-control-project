-- RC_receiver
-- implement a data receiver for the DE2 remote control
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

	-- output to display when receiver is receiving data
	rd_data 				: out std_logic;
	
	-- clock, data input, and system reset
	clk 					: in std_logic;
	data_in 				: in std_logic;
	reset 					: in std_logic:= '1');
end RC_receiver;

architecture behavior of RC_receiver is
  
  
------------------------------------------------------------------
-- leader code off duration
-- lengths of symbols '1' and '0'
-- length of transition time (error)
constant LC_off_max			: integer := LC_on_max/2;
constant one_clocks			: integer := LC_on_max/4;
constant zero_clocks		: integer := LC_on_max/8;	
constant trans_max			: integer := LC_on_max/50;	-- 2% of max
------------------------------------------------------------------
constant max_bits			: integer := 32;


-- counter for measuring the duration of the leader code-on signal
signal reading_LC_on		: std_logic := '0';
signal LC_on_counter		: integer range 0 to LC_on_max+trans_max;
-- counter for measuring the duration of the leader code-off signal
signal reading_LC_off		: std_logic := '0';
signal LC_off_counter		: integer range 0 to LC_off_max+trans_max;
-- counter for measuring the duration of the data signal
signal reading_data			: std_logic := '0';
signal clock_counter		: integer range 0 to one_clocks+trans_max;
signal checking_data		: std_logic := '0';
-- signal which determine the bit that is communicated
signal data_bit				: std_logic := '0';
-- counter to keep track of the number of bits transmitted
signal data_counter			: integer range 0 to max_bits-1;
-- signals for edge detection circuitry
signal data					: std_logic;
signal data_lead, data_follow : std_logic;
signal posedge				: std_logic;
-- shift register which holds the transmitted bits
signal shift_reg			: std_logic_vector(max_bits-1 downto 0) := (others => '0');

-- state machine signals
type state_type is (init, read_LC_on, check_LC_on_count, read_LC_off, 
		check_LC_off_count, read_data, check_data);
signal state, nxt_state		: state_type;

-- 7 segment display circuitry
component hex_to_7_seg is 
port (
	seven_seg		: out std_logic_vector(6 downto 0);
	hex				: in std_logic_vector(3 downto 0));
end component; 

begin
	-- state machine processes
	state_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				state <= init;
			else
				state <= nxt_state;
			end if;
		end if;
	end process state_proc;
	nxt_state_proc : process(state, posedge, data, LC_on_counter,LC_off_counter,data_counter)
	begin
		nxt_state <= state;		reading_LC_on <= '0';
		reading_LC_off <= '0';	reading_data <= '0';  checking_data <= '0';
		
		case state is
			when init => 
				if(posedge = '1') then
					nxt_state <= read_LC_on;
				else
					nxt_state <= init;
				end if;
			when read_LC_on =>
				reading_LC_on <= '1';
				if(data = '0') then
					nxt_state <= check_LC_on_count;
				else
					nxt_state <= read_LC_on;
				end if;
			when check_LC_on_count =>
				if ((LC_on_counter <= LC_on_max+trans_max) and (LC_on_counter >= LC_on_max-trans_max)) then
					nxt_state <= read_LC_off;
				else
					nxt_state <= init;
				end if;
			when read_LC_off =>
				reading_LC_off <= '1';
				if(posedge = '1') then
					nxt_state <= check_LC_off_count;
				else
					nxt_state <= read_LC_off;
				end if;
			when check_LC_off_count =>
				if((LC_off_counter <= LC_off_max+trans_max) and (LC_off_counter >= LC_off_max-trans_max)) then
					nxt_state <= read_data;
				else
					nxt_state <= init;
				end if;
			when read_data =>
				reading_data <= '1';
				if(posedge = '1') then
					nxt_state <= check_data;
				else
					nxt_state <= read_data;
				end if;				
			when check_data =>
				checking_data <= '1';
				if(data_counter = 31) then
					nxt_state <= init;
				else
					nxt_state <= read_data;
				end if;								
			when others =>
				nxt_state <= init;
		end case;				
	end process nxt_state_proc;
	
	
	-- start with edge detection circuitry for the posedge
	posedge <= data_lead and data_follow;
	posedge_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				data <= '0';
				data_lead <= '0';
				data_follow <= '0';
			else
				data <= data_in;
				data_lead <= data;
				data_follow <= not data_lead;
			end if;
		end if;
	end process posedge_proc;
	
	-- LC_on counter
	LC_on_counter_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then			
				if (LC_on_counter > LC_on_max+trans_max) then
					LC_on_counter <= 0;
				else
					LC_on_counter <= LC_on_counter + 1;
				end if;
			end if;
		end if;
	end process LC_on_counter_proc;
	
	-- LC_off counter
	LC_off_counter_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				--if((LC_on_counter > LC_off_max+trans_max) and rising_edge(data_in)) then
				if((LC_off_counter < LC_off_max) and rising_edge(data_in)) then
					LC_off_counter <= LC_off_counter + 1;
				else
					LC_off_counter <= 0;
				end if;
			end if;
		end if;
	end process LC_off_counter_proc;	
		
	-- -- clock counter
	-- clock_counter_proc : process(clk)
	-- begin
		-- if(rising_edge(clk)) then
			-- if((reset = '0') or (clock_counter = one_clocks+trans_max) or (clock_counter = zero_clocks+trans_max)) then
				-- clock_counter <= 0;
			-- elsif(reading_data = '1') then
				-- bit_counter <= bit_counter + 1;
			-- else
				-- bit_counter <= 0;
			-- end if;
		-- end if;
	-- end process clock counter_proc;
		
	-- -- flag to determine when we read a bit
	-- read_start_bit_proc : process(start_bit_counter, bit_counter)
	-- begin
		-- if((start_bit_counter = max_start_bit_count-1) or (bit_counter = max_bit_count-1)) then
			-- read_bit <= '1';
		-- else
			-- read_bit <= '0';
		-- end if;
	-- end process read_start_bit_proc;
		
	--processes to keep track of the number of bits read
	data_counter_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0' or data_counter = (max_bits-1) or reading_data = '0') then
				data_counter <= 0;
			elsif(reading_data = '1') then
				data_counter <= data_counter + 1;
			else
				data_counter <= 0;
			end if;
		end if;
	end process data_counter_proc;
	
	reading_data_proc : process(data_counter)
	begin
		if(data_counter = (max_bits-1)) then
			reading_data <= '0';
		else
			reading_data <= '1';
		end if;
	end process reading_data_proc;
			
	-- -- shift register process (we use little endian for the tranmitter)
	-- -- hense, a right shift register
	-- data_out <= data_reg(8 downto 1);
	-- shift_reg_proc : process(clk)
	-- begin
		-- if(rising_edge(clk)) then
			-- if(reset = '0') then
				-- data_reg <= (others => '0');
			-- elsif(read_bit = '1') then
				-- data_reg <= data_in & data_reg(9 downto 1);
			-- end if;
		-- end if;
	-- end process shift_reg_proc;
end behavior;