library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity stoper is
    Port (
        clk         : in  std_logic;  -- System clock
        reset       : in  std_logic;  -- Synchronous reset (active high)
        start       : in  std_logic;  -- Start the stoper
        duration_ns : in  integer;    -- Time in nanoseconds to measure
        time_passed : out std_logic   -- '1' once time has elapsed
    );
end stoper;

architecture Behavioral of stoper is

    -- For a 100 MHz clock, each tick = 10 ns
    constant CLK_FREQ     : integer := 100_000_000;
    constant TICK_TIME_NS : integer := 10;

    -- We'll cap the maximum target time at 1,000,000 ns = 1 ms
    -- and floor it at 10 ns
    constant MAX_TIME : integer := 1_000_000;
    constant MIN_TIME : integer := 100;

    -- Internal signals
    signal accumulated_time : integer range 0 to MAX_TIME := 0;
    signal target_time      : integer range 0 to MAX_TIME := 0;

    -- State machine definition
    type stoper_state_t is (IDLE, RUNNING, DONE);
    signal stoper_state : stoper_state_t := IDLE;

begin

    -- Synchronous process (one clock, one process) to avoid latches
    process(clk,reset)
    begin
        if reset = '1' then
            
                -- Asynchronous or synchronous reset (active high)
                -- Move to IDLE and clear all relevant signals
                stoper_state     <= IDLE;
                accumulated_time <= 0;
                target_time      <= MIN_TIME;
                time_passed      <= '0';

            elsif rising_edge(clk) then -- normal operation
                case stoper_state is

                    when IDLE =>
                        -- Output is idle
                        time_passed <= '0';

                        -- If start goes high, load the target and go RUNNING
                        if start = '1' then
                            accumulated_time <= 0;

                            if duration_ns > MAX_TIME then
                                target_time <= MAX_TIME;
                            elsif duration_ns < MIN_TIME then
                                target_time <= MIN_TIME;
                            else
                                target_time <= duration_ns;
                            end if;

                            stoper_state <= RUNNING;
                        else
                            -- Remain IDLE
                            stoper_state <= IDLE;
                        end if;

                    when RUNNING =>
                        -- Check if we've reached/exceeded target time
                        if accumulated_time >= target_time then
                            -- Done measuring
                            time_passed <= '1';
                            stoper_state <= DONE;
                        else
                            -- Accumulate more time
                            accumulated_time <= accumulated_time + TICK_TIME_NS;
                            stoper_state <= RUNNING;
                        end if;

                    when DONE =>
                        -- time_passed remains '1' until user lowers start
                        if start = '0' then
                            -- Once start is low, we can return to IDLE
                            time_passed <= '0';
                            accumulated_time <= 0;
                            stoper_state <= IDLE;
                        else
                            stoper_state <= DONE;
                        end if;

                    when others =>
                        -- Fallback (shouldn't happen)
                        stoper_state <= IDLE;
                end case;
        end if;
    end process;

end Behavioral;