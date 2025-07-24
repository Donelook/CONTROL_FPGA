library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CURRENT_SHIFT is
    Port (
        clk             : in  std_logic;            -- System clock
		clk2             : in  std_logic;            -- 100 mhz clock for timers
        reset           : in  std_logic;            -- Synchronous reset
        enable           : in  std_logic;            -- enable
        S1              : in  std_logic;            -- Signal S1
        S3              : in  std_logic;            -- Signal S3
        control_out     : out integer              -- Output from PI controller
        
     --   enable			: out std_logic
    );
end CURRENT_SHIFT;

architecture Behavioral of CURRENT_SHIFT is

    -- Declare the timer component
    component timer is
        Port (
            clk             : in  std_logic;            -- System clock (100 MHz)
            reset           : in  std_logic;            -- Synchronous reset
            start_timer     : in  std_logic;            -- Start timer
            stop_timer      : in  std_logic;            -- Stop timer
            elapsed_time_ns : out integer               -- Elapsed time in nanoseconds
        );
    end component;

    -- Declare the PI_CONTROLLER component
    component PI_CONTROLLER is
        Port (
            clk          : in  std_logic;       -- System clock
            reset        : in  std_logic;       -- Asynchronous reset
            enable       : in  std_logic;       -- Enable signal for sampling control
            setpoint     : in  integer;         -- Desired value (Integer)
            measured     : in  integer;         -- Measured value (Integer)
            kp           : in  integer;         -- Proportional gain (Integer)
            ki           : in  integer;         -- Integral gain (Integer)
            output_min   : in  integer;         -- Minimum output limit (Integer)
            output_max   : in  integer;         -- Maximum output limit (Integer)
            control_out  : out integer          -- Controller output (Integer)
        );
    end component;

	-- Define FSM states for measurement
    type meas_state_type is (IDLE, WAIT_FOR_S1, WAIT_FOR_S3);
    signal meas_state      : meas_state_type := IDLE;

    -- Input signal synchronization (to clk2 domain)
    signal S1_sync0, S1_sync1 : std_logic := '0';
    signal S3_sync0, S3_sync1 : std_logic := '0';

    -- Edge detection
    signal S1_sync_prev   : std_logic := '0';
    signal S3_sync_prev   : std_logic := '0';
    signal S1_rise        : std_logic := '0';
    signal S3_rise        : std_logic := '0';
  
	-- Timer for measuring S1 period and phase shift
    signal timer_cnt           : integer := 0;
    signal period_cnt          : integer := 0;
    signal phase_cnt           : integer := 0;

    signal period_valid        : std_logic := '0';
    signal phase_valid         : std_logic := '0';

    signal period_last         : integer := 0;
    
    -- Output pipeline (latched after measurement)
    signal pi_input            : integer := 0;

    -- PI controller output synchronization
    signal control_out_int     : integer := 0;
  
    -- Signals for timer control
    signal start_timer_s1 : std_logic := '0';
    signal stop_timer_s1  : std_logic := '0';

    signal start_timer_phase : std_logic := '0';
    signal stop_timer_phase  : std_logic := '0';

    -- Signals for elapsed times
    signal elapsed_time_ns_s1 : integer := 0;

    signal elapsed_time_ns_phase : integer := 0;



    -- Signals for phase shift calculation
    signal control_input     : integer := 0;
    signal phase_bufor       : std_logic := '0';
	

begin
	
	
    -- Instance of the timer module for S1 frequency
    timer_s1: timer
        Port map (
            clk             => clk2,
            reset           => reset,
            start_timer     => start_timer_s1,
            stop_timer      => stop_timer_s1,
            elapsed_time_ns => elapsed_time_ns_s1
        );

 

    -- Instance of the timer module for phase shift measurement
    timer_phase: timer
        Port map (
            clk             => clk2,
            reset           => reset,
            start_timer     => start_timer_phase,
            stop_timer      => stop_timer_phase,
            elapsed_time_ns => elapsed_time_ns_phase
        );

    -- Instance of the PI_CONTROLLER module
    PI_CTRL: PI_CONTROLLER
        Port map (
            clk          => clk,
            reset        => reset,
            enable       => enable,
            setpoint     => 0,  -- Setpoint is zero (0.5 - phase_shift_ratio should be zero ideally)
            measured     => control_input,
            kp           => 1,  -- Proportional gain
            ki           => 1,  -- Integral gain
            output_min   => -1000, -- Min limit for control output
            output_max   => 1000,  -- Max limit for control output
            control_out  => control_out_int
        );
		
		-- Synchronize S1/S3 to clk2 domain (2-stage synchronizer)
    process(clk2)
    begin
        if rising_edge(clk2) then
            S1_sync0 <= S1; 
            S1_sync1 <= S1_sync0;
            S3_sync0 <= S3; 
            S3_sync1 <= S3_sync0;
        end if;
    end process;
    
    -- Rising edge detection for S1/S3 (clk2 domain)
    process(clk2)
    begin
        if rising_edge(clk2) then
            S1_sync_prev <= S1_sync1;
            S3_sync_prev <= S3_sync1;
            if S1_sync1 = '1' AND S1_sync_prev = '0' then
                    	S1_rise <= '1';
				else 
						S1_rise <= '0';
            end if;
            
            
            if S3_rise = '1' AND S3_sync_prev = '0' then
                    	S3_rise <= '1';
				else 
						S3_rise <= '0';
            end if;
        end if;
    end process;
    
        -- FSM for measuring period and phase difference
    process(clk2, reset)
    begin
        if reset = '1' then
            meas_state    <= IDLE;
            timer_cnt     <= 0;
            period_cnt    <= 0;
            phase_cnt     <= 0;
            period_valid  <= '0';
            phase_valid   <= '0';
            period_last   <= 0;
        elsif rising_edge(clk2) then
            period_valid <= '0'; phase_valid <= '0';
            case meas_state is
                when IDLE =>
                    if S1_rise = '1' then
                    	stop_timer_s1 <= '0';
                        start_timer_s1  <= '1';          -- Start new period count
                        
                        stop_timer_phase <= '0';
                        start_timer_phase  <= '1';          -- Start phase count
                        
                        meas_state <= WAIT_FOR_S3;

                    end if;
                when WAIT_FOR_S3 =>

                    if S3_rise = '1' then
                        start_timer_phase  <= '0';         
                        stop_timer_phase <= '1';				-- stop phase count
                        phase_valid <= '1';
                        -- Continue waiting for next S1 rising edge for full period
                    end if;
                    if S1_rise = '1' and start_timer_s1 = '1' and phase_valid = '1' then
                        period_cnt    <= elapsed_time_ns_s1;
                        period_last   <= elapsed_time_ns_s1;
                        period_valid  <= '1';

                        start_timer_s1  <= '0';          -- Start new period count
                        stop_timer_s1 <= '1';
                        
                        meas_state    <= IDLE;

                    end if;
                when others =>
                    meas_state <= IDLE;
            end case;
        end if;
    end process;

  

    -- Calculate the phase shift ratio and feed it into the PI controller
    process(clk, elapsed_time_ns_s1, elapsed_time_ns_phase)
    begin
		if  rising_edge(clk) AND enable = '1' AND phase_valid = '1' then
        -- Normalize and adjust the phase shift input for PI controller
        control_input <=  (elapsed_time_ns_s1/2 - elapsed_time_ns_phase)/64; -- Adjusting the phase shift change from 8 to 1048576

		end if;
       
    end process;
   control_out <= control_out_int;
end Behavioral;