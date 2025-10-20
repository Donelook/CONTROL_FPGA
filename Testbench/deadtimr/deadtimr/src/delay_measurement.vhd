library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity delay_measurement is
    Port (
        clk             : in  std_logic;  -- 100 MHz clock
        reset           : in  std_logic;  -- Synchronous reset (active high)
        delay_tr_signal : in  std_logic;  -- TR signal for measuring period (async to clk)
        delay_hc_signal : in  std_logic;  -- HC signal for measuring period (async to clk)
        delay_tr        : out integer;    -- Measured period for TR (ns)
        delay_hc        : out integer     -- Measured period for HC (ns)
    );
end delay_measurement;

architecture Behavioral of delay_measurement is

    --------------------------------------------------------------------
    -- Timer component
    --------------------------------------------------------------------
    component timer is
        Port (
            clk             : in  std_logic;  -- 100 MHz system clock
            reset           : in  std_logic;  -- Synchronous reset
            start_timer     : in  std_logic;  -- 1-cycle pulse: start
            stop_timer      : in  std_logic;  -- 1-cycle pulse: stop & latch
            elapsed_time_ns : out integer     -- Latched elapsed time (ns)
        );
    end component;

    --------------------------------------------------------------------
    -- Control / data signals
    --------------------------------------------------------------------
    -- TR channel
    signal start_timer_tr   : std_logic := '0';
    signal stop_timer_tr    : std_logic := '0';
    signal elapsed_time_tr  : integer   := 0;
    signal delay_tr_reg     : integer   := 10;

    -- HC channel
    signal start_timer_hc   : std_logic := '0';
    signal stop_timer_hc    : std_logic := '0';
    signal elapsed_time_hc  : integer   := 0;
    signal delay_hc_reg     : integer   := 10;

    -- FSM
    type meas_state is (IDLE, WAIT_SECOND_EDGE);

    -- TR FSM + edge detect (on synchronized signal)
    signal tr_state         : meas_state := IDLE;
    signal tr_sync_0        : std_logic := '0';
    signal tr_sync_1        : std_logic := '0';
    signal tr_prev          : std_logic := '0';

    -- HC FSM + edge detect (on synchronized signal)
    signal hc_state         : meas_state := IDLE;
    signal hc_sync_0        : std_logic := '0';
    signal hc_sync_1        : std_logic := '0';
    signal hc_prev          : std_logic := '0';

    -- Range clamps
    constant MIN_MEASURE    : integer := 10;        -- ns
    constant MAX_MEASURE    : integer := 1_000_000; -- ns

begin

    --------------------------------------------------------------------
    -- Timer instances
    --------------------------------------------------------------------
    delay_tr_timer: timer
        port map (
            clk             => clk,
            reset           => reset,
            start_timer     => start_timer_tr,
            stop_timer      => stop_timer_tr,
            elapsed_time_ns => elapsed_time_tr
        );

    delay_hc_timer: timer
        port map (
            clk             => clk,
            reset           => reset,
            start_timer     => start_timer_hc,
            stop_timer      => stop_timer_hc,
            elapsed_time_ns => elapsed_time_hc
        );

    --------------------------------------------------------------------
    -- 2-FF synchronizers for asynchronous inputs
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tr_sync_0 <= '0';
                tr_sync_1 <= '0';
                hc_sync_0 <= '0';
                hc_sync_1 <= '0';
            else
                tr_sync_0 <= delay_tr_signal;
                tr_sync_1 <= tr_sync_0;

                hc_sync_0 <= delay_hc_signal;
                hc_sync_1 <= hc_sync_0;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- TR measurement FSM (1st rising edge = start pulse, 2nd = stop pulse)
    --------------------------------------------------------------------
    process(clk)
        variable tr_rising : boolean;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tr_state       <= IDLE;
                tr_prev        <= '0';
                start_timer_tr <= '0';
                stop_timer_tr  <= '0';
                delay_tr_reg   <= MIN_MEASURE;
            else
                -- edge detect (synchronized signal)
                tr_rising := (tr_prev = '0') and (tr_sync_1 = '1');
                tr_prev   <= tr_sync_1;

                -- default: deassert pulses
                start_timer_tr <= '0';
                stop_timer_tr  <= '0';

                case tr_state is
                    when IDLE =>
                        if tr_rising then
                            start_timer_tr <= '1';         -- 1-cycle start pulse
                            tr_state       <= WAIT_SECOND_EDGE;
                        end if;

                    when WAIT_SECOND_EDGE =>
                        if tr_rising then
                            stop_timer_tr <= '1';          -- 1-cycle stop pulse
                            -- Latch the measurement on stop:
                            if (elapsed_time_tr > MIN_MEASURE) and (elapsed_time_tr < MAX_MEASURE) then
                                delay_tr_reg <= elapsed_time_tr;
                            elsif elapsed_time_tr >= MAX_MEASURE then
                                delay_tr_reg <= MAX_MEASURE;
                            else
                                delay_tr_reg <= MIN_MEASURE;
                            end if;
                            tr_state <= IDLE;
                        end if;

                    when others =>
                        tr_state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- HC measurement FSM (same as TR)
    --------------------------------------------------------------------
    process(clk)
        variable hc_rising : boolean;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                hc_state       <= IDLE;
                hc_prev        <= '0';
                start_timer_hc <= '0';
                stop_timer_hc  <= '0';
                delay_hc_reg   <= MIN_MEASURE;
            else
                -- edge detect (synchronized signal)
                hc_rising := (hc_prev = '0') and (hc_sync_1 = '1');
                hc_prev   <= hc_sync_1;

                -- default: deassert pulses
                start_timer_hc <= '0';
                stop_timer_hc  <= '0';

                case hc_state is
                    when IDLE =>
                        if hc_rising then
                            start_timer_hc <= '1';         -- 1-cycle start pulse
                            hc_state       <= WAIT_SECOND_EDGE;
                        end if;

                    when WAIT_SECOND_EDGE =>
                        if hc_rising then
                            stop_timer_hc <= '1';          -- 1-cycle stop pulse
                            -- Latch the measurement on stop:
                            if (elapsed_time_hc > MIN_MEASURE) and (elapsed_time_hc < MAX_MEASURE) then
                                delay_hc_reg <= elapsed_time_hc;
                            elsif elapsed_time_hc >= MAX_MEASURE then
                                delay_hc_reg <= MAX_MEASURE;
                            else
                                delay_hc_reg <= MIN_MEASURE;
                            end if;
                            hc_state <= IDLE;
                        end if;

                    when others =>
                        hc_state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Always drive outputs from the registered values
    --------------------------------------------------------------------
    delay_tr <= delay_tr_reg;
    delay_hc <= delay_hc_reg;

end Behavioral;
