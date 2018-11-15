-- RC_receiver
-- Implement a data receiver for the DE2 remote control
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
 entity RC_receiver is
generic (
	-- number of clks for the leader code-on signal (assumine 50MHZ clk)
	LC_on_max : integer := 450000;
	-- Counter
	cnt: integer := 49779500
	);
port(
	-- Outputs to the 8 7-segment displays, the remote control
	-- Outputs 32 bits of binary data (each byte displayed as 2 7-segment displays)
	hex7 : out std_logic_vector (6 downto 0);
	hex6 : out std_logic_vector (6 downto 0);
	hex5 : out std_logic_vector (6 downto 0);
	hex4 : out std_logic_vector (6 downto 0);
	hex3 : out std_logic_vector (6 downto 0);
	hex2 : out std_logic_vector (6 downto 0);
	hex1 : out std_logic_vector (6 downto 0);
	hex0 : out std_logic_vector (6 downto 0);
	-- output to display when receiver is receiving data
	rd_data : out std_logic;
	-- Clk, data input and system reset
	clk : in std_logic;
	data_in : in std_logic;
	reset : in std_logic);
end RC_receiver;
 architecture behavior of RC_receiver is
 -- 7 segment display circuitry
component hex_to_7_seg is
	port (seven_seg :out std_logic_vector (6 downto 0);
		hex : in std_logic_vector (3 downto 0));
end component;
------------------------------------------------------------------------------------------
-- leader code off duration
-- lengths of symbols '1' and '0'
-- length of transition time (error)
constant LC_off_max : integer := LC_on_max/2;
constant one_clocks : integer := LC_on_max/4 ;
constant zero_clocks : integer := LC_on_max/8 ;
constant trans_max : integer := LC_on_max/50 ; --2% of max
------------------------------------------------------------------------------------------
constant max_bits	: integer := 32;
-- counter for measuring the duration of the leader code-on sig
signal reading_LC_on : std_logic := '0';
signal LC_on_counter : integer range 0 to LC_on_max+trans_max;
-- counter for measuring the duration of the leader code-off sig
signal reading_LC_off : std_logic := '0';
signal LC_off_counter : integer range 0 to LC_off_max+trans_max;
-- counter for measurinf the duration of the data sig
signal reading_data : std_logic := '0';
signal clock_counter : integer range 0 to one_clocks+trans_max;
signal checking_data : std_logic := '0';
-- sig which determine the bit that is communicated
signal data_bit : std_logic := '0';
-- counter to keep track of the number of bits transmitted
signal data_counter : integer range 0 to max_bits -1;
-- signals for edge detection circuitry
signal data : std_logic;
signal data_lead, data_follow : std_logic;
signal posedge : std_logic:='0';
-- Counter 1 and counter2 signals
signal counter_one: integer range 0 to cnt;
signal counter_two: integer range 0 to cnt-9000;
signal pulse_counter_clear: std_logic:= '0';
signal LC_counter_clear: std_logic :='0';
-- shift register which holds the transmitted bits
signal shift_reg :std_logic_vector (max_bits-1 downto 0) := ( others => '0');
-- state machine signals
type state_type is (init_state, read_LC_on, check_LC_on_count, read_LC_off, check_LC_off_count, read_data, check_data);
signal state, nxt_state :state_type;
begin
	--Process for posedge
	posedge_proc:process(posedge)
	begin
		if(rising_edge(data_in)) then
			posedge<='1';
		else
			posedge<='0';
	end if;
	end process posedge_proc;
	
	--Counter one implementation
	--It counts the amount of pulses that have passed since its last reset
	Pulse_counter: process(clk)
	begin
		if rising_edge(clk) then
			if pulse_counter_clear = '1' then
				counter_one <= 0;
			else 
				counter_one <= counter_one + 1;
			end if;
		end if;
	end process;
	
	--Counter two Implementation
	--Counts for LC_on & LC_off
	LC_counter: process(clk)
	begin
		if rising_edge(clk) then
			if LC_counter_clear = '1' then
				counter_two <= 0;
			else
				counter_two <= counter_two + 1;
			end if;
		end if;
	end process;
	
	--Check on process
	LC_proc: process(LC_on_counter)
	begin
		if(counter_one> LC_on_counter + trans_max)then
			pulse_counter_clear <= '1';
		elsif(counter_two > LC_off_counter-trans_max)then
			LC_counter_clear <= '1';
		end if;
	end process LC_proc;
	
	
	-- Defining the counters properly for the falling edge 
	
	
	 --State Machine Processes
	 state_proc: process(clk)
	 begin 
		if(rising_edge(clk)) then	
			if(reset = '0') then
				state <= init_state;
			else
				state <= nxt_state;
			end if;
		end if;
	end process state_proc;
	
			
	-- TODO: Correct the sensitivity list
	nxt_state_proc: process(state)
	begin	
		-- TODO: Check if we need any control sig and if Yes, implement it below
		nxt_state <= state;
		
		case state is
			-- Initialization state
			when init_state =>
				if posedge = '1' then
					nxt_state <= read_LC_on;
				else 
					nxt_state <= init_state;
				end if;
			when read_LC_on =>
				if data = '0' then
					nxt_state <= check_LC_on_count;
				else 
					nxt_state <= read_LC_on;
				end if;
			when  check_LC_on_count =>
				-- TODO: Check if the if statement condition is correct
				if (LC_on_counter>=1 and LC_on_counter<= 0)then 
					nxt_state <= read_LC_off;
				else 
					nxt_state <= init_state;
				end if;
			when read_LC_off =>
				if posedge = '1' then
					nxt_state <= check_LC_off_count;
				else 
					nxt_state <= read_LC_off;
				end if;
			when check_LC_off_count =>
				-- TODO: Check if the if statement condition is correct
				if LC_off_counter = 1 then
					nxt_state <= read_data;
				else 
					nxt_state <= init_state;
				end if;
			when read_data =>
				if posedge = '1' then
					nxt_state <= check_data;
				else 
					nxt_state <= read_data;
				end if;
			when check_data =>
				if data_counter /= 31 then
					nxt_state <= read_data;
				else 
					nxt_state <= init_state;
				end if;
			-- TODO: Implement state machine for LED Illumination
		end case;
	end process nxt_state_proc;
end behavior;