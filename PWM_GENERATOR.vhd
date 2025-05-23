library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PWM_GENERATOR is
    Port (
        clk          : in  std_logic;  -- 100 MHz system clock
        reset        : in  std_logic;  -- Synchronous reset
        duty_input   : in  integer;    -- Input value from -1000 to 1000
        pwm_out      : out std_logic   -- PWM output signal
    );
end PWM_GENERATOR;

architecture Behavioral of PWM_GENERATOR is
    -- Constants
    constant PWM_FREQUENCY : integer := 1_000_00;  -- Desired PWM frequency in Hz 100khz
    constant CLK_FREQUENCY : integer := 100_000_000;  -- Clock frequency in Hz 100Mhz
    constant MAX_COUNT : integer := CLK_FREQUENCY / PWM_FREQUENCY - 1;

    -- Signals
    signal counter   : integer range 0 to MAX_COUNT := 0;
    signal threshold : integer range 0 to MAX_COUNT := 0; -- threshold is number thicks when pwm is turn off - duty cycle  
	signal threshold_ACC : integer range 0 to MAX_COUNT := 0; -- threshold is number thicks when pwm is turn off - duty cycle 
	signal change_flag : integer range 0 to 2 := 0; -- threshold is number thicks when pwm is turn off - duty cycle 
begin

    -- Process for PWM generation
    process(clk, reset)
    begin
        if reset = '1' then
            counter <= 0;
            pwm_out <= '0';
			threshold <= 450;
			threshold_ACC <= 450;

        elsif rising_edge(clk) then

            if counter < MAX_COUNT then
                counter <= counter + 1;
            else 
				change_flag <= 1;
                counter <= 0;
            end if;
		-- Scale the input range -1000 to 1000 to 0 to MAX_COUNT
        	-- 0 corresponds to 45% duty cycle (half the MAX_COUNT)
        	-- -1000 corresponds to 6% duty cycle, 1000 to 84% duty cycle 0.2Vavg to 2.8Vavg
        	if duty_input < 1001 AND duty_input > -1001 then
         		threshold_ACC <= ((duty_input * 399) + 460800) / 1024; -- 
			else
			threshold_ACC <= 450;
			end if;
		if change_flag <= 1 then 
			   threshold <= threshold_ACC;
			end if;
            -- Set the PWM output based on the counter and threshold
            if counter < threshold then	
				change_flag <= 0;
                pwm_out <= '1';
            else				
				change_flag <= 0;
                pwm_out <= '0';
            end if;
        end if;
    end process;

    -- Process to calculate the threshold based on duty_input
   -- process(clk, reset, duty_input)
   -- begin
        -- Scale the input range -1000 to 1000 to 0 to MAX_COUNT
        -- 0 corresponds to 45% duty cycle (half the MAX_COUNT)
        -- -1000 corresponds to 6% duty cycle, 1000 to 84% duty cycle 0.2Vavg to 2.8Vavg
      --  if duty_input < 1001 AND duty_input > -1001 then
      --   threshold <= ((duty_input * 399) + 460800) / 1024; -- 
	--else 
	--threshold <= 450;
	--end if;
    --end process;
end Behavioral;

-- 2000 resolution of duty 
-- LSB 3.3mV 

-- 0.384 A/V -> 1.26 mA LSB