library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity delay_measurement is
    Port (
        clk             : in  std_logic;  -- 100 MHz clock
        reset           : in  std_logic;  -- Synchronous reset (active high)
        delay_tr_signal : in  std_logic;  -- TR signal for measuring period
        delay_hc_signal : in  std_logic;  -- HC signal for measuring period
        delay_tr        : out integer;    -- Measured period for TR
        delay_hc        : out integer     -- Measured period for HC
    );
end delay_measurement;

architecture Behavioral of delay_measurement is

    --------------------------------------------------------------------
    -- Timer component 
    --------------------------------------------------------------------
    component timer is
        Port (
            clk             : in  std_logic;   -- 100 MHz system clock
            reset           : in  std_logic;   -- Synchronous reset
            start_timer     : in  std_logic;   -- Start timer
            stop_timer      : in  std_logic;   -- Stop timer
            elapsed_time_ns : out integer      -- Elapsed time in nanoseconds
        );
    end component;

    --------------------------------------------------------------------
    -- Instances of the two timer modules (for TR and HC)
    --------------------------------------------------------------------
    signal start_timer_tr  : std_logic := '0';
    signal stop_timer_tr   : std_logic := '0';
    signal elapsed_time_tr : integer   := 0;

    signal start_timer_hc  : std_logic := '0';
    signal stop_timer_hc   : std_logic := '0';
    signal elapsed_time_hc : integer   := 0;

    -- Actual output signals
    signal delay_tr_reg : integer := 10;
    signal delay_hc_reg : integer := 10;

    --------------------------------------------------------------------
    -- Synchronous edge-detection state machines for TR and HC
    --------------------------------------------------------------------
    type meas_state is (IDLE, WAIT_SECOND_EDGE);

    -- TR signals / state
    signal tr_state     : meas_state := IDLE;
    signal prev_tr_sig  : std_logic  := '0';

    -- HC signals / state
    signal hc_state     : meas_state := IDLE;
    signal prev_hc_sig  : std_logic  := '0';

    -- Range clamps
    constant MIN_MEASURE : integer := 10;       -- Minimum reported time
    constant MAX_MEASURE : integer := 1000000;  -- Maximum reported time
attribute syn_noclockbuf : boolean;
attribute syn_noclockbuf of delay_hc_signal : signal is true;
attribute syn_noclockbuf of delay_hc_reg : signal is true;

begin
    --------------------------------------------------------------------
    -- Timer Instantiations
    --------------------------------------------------------------------
    delay_tr_timer: timer
        Port map (
            clk             => clk,
            reset           => reset,
            start_timer     => start_timer_tr,
            stop_timer      => stop_timer_tr,
            elapsed_time_ns => elapsed_time_tr
        );

    delay_hc_timer: timer
        Port map (
            clk             => clk,
            reset           => reset,
            start_timer     => start_timer_hc,
            stop_timer      => stop_timer_hc,
            elapsed_time_ns => elapsed_time_hc
        );

    --------------------------------------------------------------------
    -- PROCESS #1: TR Measurement (fully synchronous)
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset everything
               -- tr_state      <= IDLE;
                prev_tr_sig   <= '0';
                start_timer_tr <= '0';
                stop_timer_tr  <= '0';
                delay_tr_reg  <= MIN_MEASURE;
            else
                -- Latch previous cycle's TR signal to detect rising edge
                prev_tr_sig <= delay_tr_signal;
				   start_timer_tr <= '0';
                   stop_timer_tr  <= '0';


                -- Main TR state machine
                case tr_state is

                    when IDLE =>
                        -- If we detect a rising edge of delay_tr_signal
                        if (prev_tr_sig = '0') and (delay_tr_signal = '1') then
                            -- Start the timer
                            start_timer_tr <= '1';
                           -- stop_timer_tr  <= '0';
                            tr_state       <= WAIT_SECOND_EDGE;
                        else
                            -- Keep outputs inactive
                           -- start_timer_tr <= '0';
                           -- stop_timer_tr  <= '0';
                           -- tr_state       <= IDLE;
                        end if;

                    when WAIT_SECOND_EDGE =>
                        -- If we detect another rising edge, stop the timer
                        if (prev_tr_sig = '0') and (delay_tr_signal = '1') then
                            --start_timer_tr <= '0';
                            stop_timer_tr  <= '1';
                            tr_state       <= IDLE;  -- measurement done, go back to IDLE  
							
							-- Check the measured time each cycle
                -- (Clamp to [10, 1_000_000], store in delay_tr_reg)
                			if elapsed_time_tr > MIN_MEASURE and elapsed_time_tr < MAX_MEASURE then
                   				 delay_tr_reg <= elapsed_time_tr;
               				 elsif elapsed_time_tr > MAX_MEASURE then
                    			delay_tr_reg <= MAX_MEASURE;
                			end if;
                        else
                            -- Remain in this state, keep timer running
                           -- start_timer_tr <= '1';
                           -- stop_timer_tr  <= '0';
                            --tr_state       <= WAIT_SECOND_EDGE;
                        end if;

                    when others =>
                        tr_state <= IDLE;

                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- PROCESS #2: HC Measurement (fully synchronous)
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
               -- hc_state      <= IDLE;
                prev_hc_sig   <= '0';
                start_timer_hc <= '0';
                stop_timer_hc  <= '0';
                delay_hc_reg  <= MIN_MEASURE;
            else
                -- Edge detection
                prev_hc_sig <= delay_hc_signal;

                -- Clamp and store measurement
                if elapsed_time_hc > MIN_MEASURE and elapsed_time_hc < MAX_MEASURE then
                    delay_hc_reg <= elapsed_time_hc;
                elsif elapsed_time_hc > MAX_MEASURE then
                    delay_hc_reg <= MAX_MEASURE;
                end if;

                case hc_state is

                    when IDLE =>
                        if (prev_hc_sig = '0') and (delay_hc_signal = '1') then
                            start_timer_hc <= '1';
                            stop_timer_hc  <= '0';
                            hc_state       <= WAIT_SECOND_EDGE;
                        else
                            start_timer_hc <= '0';
                            stop_timer_hc  <= '0';
                            hc_state       <= IDLE;
                        end if;

                    when WAIT_SECOND_EDGE =>
                        if (prev_hc_sig = '0') and (delay_hc_signal = '1') then
                            start_timer_hc <= '0';
                            stop_timer_hc  <= '1';
                            hc_state       <= IDLE;
                        else
                            start_timer_hc <= '1';
                            stop_timer_hc  <= '0';
                            hc_state       <= WAIT_SECOND_EDGE;
                        end if;

                    when others =>
                        hc_state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Drive the outputs from our registered signals
    --------------------------------------------------------------------
    delay_tr <= delay_tr_reg;
    delay_hc <= delay_hc_reg;

end Behavioral;