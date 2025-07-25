-- ###################################################################
-- # Title       : Main
-- # Description : Interleaved boost converter 400V -> 800V, 10kW Control
-- #
-- # Author      : Michal Karas
-- # Date        : 24.09.2024
-- #
-- # Target Device  : [FPGA/ASIC Device (e.g., iCE40UP5K)]
-- # Clock Frequency: 100 MHz
-- #
-- # Revision History
-- # Rev  Date        Author         Description
-- # ---  ----------- -------------- ---------------------------------
-- # 1.0  24.09.2024  Michal Karas   Initial version
-- #
-- ###################################################################
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library sb_ice40_components_syn;
use sb_ice40_components_syn.components.all;


entity MAIN is
    Port (
        -- Clock and control signals
        --clk_12mhz      : in  std_logic;   -- 12 MHz system clock for PLL
        reset          : in  std_logic;   -- Reset signal
        start_stop     : in  std_logic;   -- Start/Stop control

        -- Current sensing signals
        il_max_comp1   : in  std_logic;   -- Current limit comparator 1 (max)
        il_max_comp2   : in  std_logic;   -- Current limit comparator 2 (max)
        il_min_comp1   : in  std_logic;   -- Current limit comparator 1 (min)
        il_min_comp2   : in  std_logic;   -- Current limit comparator 2 (min)

        -- Physical delay measurement signals
        delay_tr_input : in  std_logic;   -- Physical input signal for delay_tr
        delay_hc_input : in  std_logic;   -- Physical input signal for delay_hc

        -- Transistor control outputs (for driving transistors)
        s1_phy             : out std_logic;
        s2_phy             : out std_logic;
        s3_phy             : out std_logic;
        s4_phy             : out std_logic;

        -- PWM output to be read by the microcontroller
        pwm_output     : out std_logic;    -- Output PWM signal from current_shift
        
        rgb_r              : out std_logic;
        rgb_g              : out std_logic;
        rgb_b              : out std_logic
        
      --  T01  			: out std_logic;   -- test signal
       -- T12    			: out std_logic;   -- test signal
      --  T23    			: out std_logic;   -- test signal
       -- T45    			: out std_logic		-- test signal
      --  clock_output		: out std_logic
    );
end MAIN;

architecture Behavioral of MAIN is
	-- Internal signal for the 12 MHz clock from HFOSC
	signal clk_12mhz : std_logic;
    signal osc_enable   : std_logic := '1';  -- Enable oscillator
    signal osc_powerup  : std_logic := '1';  -- Power up oscillator
    -- Internal Oscillator Component Declaration
    component SB_HFOSC  
	GENERIC( CLKHF_DIV :string :="0b10");
		PORT(
        CLKHFEN: IN STD_LOGIC ;
        CLKHFPU: IN STD_LOGIC;
        CLKHF:OUT STD_LOGIC
        );
	END COMPONENT;

	attribute CLKHF_DIV : string;
-- PLL Component Declaration
    component ICE40_MAIN_PROGRAM_100MHZ_pll
        Port (
            REFERENCECLK : in  std_logic;
            PLLOUTCORE   : out std_logic;
            PLLOUTGLOBAL : out std_logic;
            RESET        : in  std_logic
        );
    end component;
    
    -- Component declaration for current_shift
    component current_shift
        Port (
            clk            : in  std_logic;
            clk2           : in  std_logic;
            reset          : in  std_logic;
            enable          : in  std_logic;
            S1             : in  std_logic;
            S3             : in  std_logic;
            control_out    : out integer
            
        );
    end component;

    -- Component declaration for PWM_GENERATOR
    component PWM_GENERATOR
        Port (
            clk        : in  std_logic;
            reset      : in  std_logic;
            duty_input : in  integer;
            pwm_out    : out std_logic
        );
    end component;

    -- Component declaration for delay_measurement
    component delay_measurement
        Port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            delay_tr_signal : in  std_logic;
            delay_hc_signal : in  std_logic;
            delay_tr        : out integer;
            delay_hc        : out integer
        );
    end component;
    
	component SB_DFF
		Port  (
			Q : out std_logic;-- Registered Output
			C : in  std_logic; -- Clock
			D : in  std_logic -- Data
		);
		end component;
    -- Component declaration for PHASE_CONTROLLER MASTER
    component PHASE_CONTROLLER
        Port (
            clk           : in  std_logic;
            reset         : in  std_logic;
            start         : in  std_logic;
            IL_max_comp   : in  std_logic;
            IL_min_comp   : in  std_logic;
            delay_hc      : in  integer;
            delay_tr      : in  integer;
            S1            : out std_logic;
            S2            : out std_logic;
            T01  			: out std_logic;   -- test signal
        	T12    			: out std_logic;   -- test signal
        	T23    			: out std_logic;   -- test signal
        	T45    			: out std_logic   -- test signal
        );
    end component;
    -- Component declaration for PHASE_CONTROLLER SECOND SLAVE
    component PHASE_CONTROLLER_SECOND
        Port (
            clk           : in  std_logic;
            reset         : in  std_logic;
            start         : in  std_logic;
            start_flag    : in  std_logic;
            IL_max_comp   : in  std_logic;
            IL_min_comp   : in  std_logic;
            delay_hc      : in  integer;
            delay_tr      : in  integer;
            S1            : out std_logic;
            S2            : out std_logic;
            T01  			: out std_logic;   -- test signal
        	T12    			: out std_logic;   -- test signal
        	T23    			: out std_logic;   -- test signal
        	T45    			: out std_logic   -- test signal
        );
    end component;
	-- RGB module to control RGB led on control board
   component SB_RGBA_DRV
        generic (
        		CURRENT_MODE : string := "0b0";
                RGB0_CURRENT : string := "0b000000";
                RGB1_CURRENT : string := "0b000000";
                RGB2_CURRENT : string := "0b000000"
                );
        port (
            CURREN   : in  std_logic;        -- Enable current control
            RGBLEDEN : in  std_logic;        -- Enable RGB LED driver
            RGB0PWM  : in  std_logic;        -- PWM for Red
            RGB1PWM  : in  std_logic;        -- PWM for Green
            RGB2PWM  : in  std_logic;        -- PWM for Blue
            RGB0     : out std_logic;        -- Red LED output
            RGB1     : out std_logic;        -- Green LED output
            RGB2     : out std_logic         -- Blue LED output
        );
    end component;
    
    
    -- Internal signals for clocking and control
    signal clk_100mhz         : std_logic;   -- PLL generated 100 MHz clock
    

    -- Signals for delay measurement
    signal measured_delay_tr  : integer := 0;
    signal measured_delay_hc  : integer := 0;
        
    signal delay_tr_d1 : std_logic := '0';
    signal delay_tr_d2 : std_logic := '0';
    signal delay_hc_d1 : std_logic := '0';
    signal delay_hc_d2 : std_logic := '0';

    -- Signals for current shift and PWM duty cycle
    signal pwm_duty_input     : integer := 0;  -- Output of current_shift to control the PWM duty cycle
    --signal pwm_duty_input_test     : integer := 500;  -- Output of current_shift to control the PWM duty cycle
          -- Phase shift between S1 and S3
--	signal S1_buffor     : std_logic := '0';       -- 
  --  signal S3_buffor     : std_logic := '0';       -- 
	
	--- RGB signal
	signal red : std_logic; 
	signal green : std_logic; 
	signal blue : std_logic; 

	 signal    il_max_comp1_D1  :  std_logic := '0';   -- Current limit comparator 1 (max)
     signal    il_max_comp1_D2   :  std_logic := '0';   -- Current limit comparator 1 (max)
     signal    il_min_comp1_D1   :  std_logic := '0';
     signal    il_min_comp1_D2   :  std_logic := '0';
     
     signal 	il_max_comp2_D1  :  std_logic := '0';   -- Current limit comparator 1 (max)
     signal    il_max_comp2_D2   :  std_logic := '0';   -- Current limit comparator 1 (max)
     signal    il_min_comp2_D1   :  std_logic := '0';
     signal    il_min_comp2_D2   :  std_logic := '0';
     
     signal clk_10khz : std_logic := '0';
     constant DIVISOR : integer := 5249;  -- Half-period for 50% duty
     signal counter   : integer range 0 to DIVISOR-1 := 0;
     
     signal shift_flag_start : std_logic := '0';
     --attribute syn_global_buffers : integer;
     --architecture behave of syn_global_buffers is 10; 
     --signal    delay_hc_D1   :  std_logic := '0';
    -- signal    delay_hc_D2   :  std_logic := '0'; 
    -- signal    delay_tr_D1   :  std_logic := '0';
     --signal    delay_tr_D2   :  std_logic := '0';
begin
	osc_enable   <= '1';  -- Enable oscillator
     	osc_powerup  <= '1';  -- Power up oscillator

	-- Instantiate the internal high-frequency oscillator (HFOSC)
   	osc:SB_HFOSC
		generic map
		(
  			CLKHF_DIV     =>"0b10"    --12Mhz
		)
		port map
		(
  			CLKHFEN   =>'1',
  			CLKHFPU   =>'1',
  			CLKHF => clk_12mhz
		);

		--reset<= error_pin;

   -- PLL Instance for clock generation (12 MHz to 100.5 MHz)
    pll_inst: ICE40_MAIN_PROGRAM_100MHZ_pll
        Port map (
            REFERENCECLK => clk_12mhz,    	-- 12 MHz input clock
            PLLOUTCORE   => open,   		-- Not used
            PLLOUTGLOBAL => clk_100mhz,     -- 100 MHz output clock
            RESET        => not reset        	-- Reset input for PLL
        );
	
		
		process(clk_100mhz, reset)
    begin
        if reset = '1' then
            counter <= 0;
            clk_10khz <= '0';
        elsif rising_edge(clk_100mhz) then
            if counter = DIVISOR-1 then
                counter <= 0;
                clk_10khz <= not clk_10khz;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

	--	process(clk_100mhz)
	--	begin
    --		if rising_edge(clk_100mhz) then
       --		 	delay_hc_D1 <= delay_hc_input;  -- First DFF
       -- 		delay_hc_D2 <= delay_hc_D1;        -- Second DFF (reduces metastability)
    --		end if;
	--	end process;


	--	process(clk_100mhz)
	--	begin
    	--	if rising_edge(clk_100mhz) then
       	--	 	delay_tr_D1 <= delay_tr_input;  -- First DFF
        --		delay_tr_D2 <= delay_tr_D1;        -- Second DFF (reduces metastability)
    	--	end if;
		--end process;
		
		-- Double D flip flop to synchronize and prevent from metastability
		SB_DFF_inst_DELAY_TR1: SB_DFF
		port map (
			Q => delay_tr_d1, -- Registered Output
			C => clk_100mhz, -- Clock
			D => delay_tr_input -- Data
		);
		SB_DFF_inst_DELAY_TR2: SB_DFF
		port map (
			Q => delay_tr_d2, -- Registered Output
			C => clk_100mhz, -- Clock
			D => delay_tr_d1 -- Data
		);
		
	SB_DFF_inst_DELAY_HC1: SB_DFF
		port map (
			Q => delay_hc_d1, -- Registered Output
			C => clk_100mhz, -- Clock
			D => delay_hc_input-- Data
		);
		SB_DFF_inst_DELAY_HC2: SB_DFF
		port map (
			Q => delay_hc_d2, -- Registered Output
			C => clk_100mhz, -- Clock
			D => delay_hc_d1 -- Data
		);
		
    -- Instantiate delay_measurement module for measuring delay_tr and delay_hc
    delay_measurement_inst: delay_measurement
        Port map (
            clk             => clk_100mhz,
            reset           => reset,
            delay_tr_signal => delay_tr_d2,
            delay_hc_signal => delay_hc_d2,
            delay_tr        => measured_delay_tr,  -- Output measured TR delay
            delay_hc        => measured_delay_hc   -- Output measured HC delay
        );
        
        -- Double D flip flop to synchronize and prevent from metastability
	SB_DFF_inst_PH1_MAX_D1: SB_DFF
		port map (
			Q => il_max_comp1_D1, -- Registered Output
			C => clk_100mhz, -- Clock
			D => il_max_comp1 -- Data
		);
		SB_DFF_inst_PH1_MAX_D2: SB_DFF
		port map (
			Q => il_max_comp1_D2, -- Registered Output
			C => clk_100mhz, -- Clock
			D => il_max_comp1_D1 -- Data
		);
		
	SB_DFF_inst_PH1_MIN_D1: SB_DFF
		port map (
			Q => il_min_comp1_D1, -- Registered Output
			C => clk_100mhz, -- Clock
			D => il_min_comp1 -- Data
		);
		SB_DFF_inst_PH1_MIN_D2: SB_DFF
		port map (
			Q => il_min_comp1_D2, -- Registered Output
			C => clk_100mhz, -- Clock
			D => il_min_comp1_D1 -- Data
		);
-- End of SB_DFF instantiation
    -- Instantiate the first PHASE_CONTROLLER module (for controlling S1 and S2)
    phase_controller_inst1: PHASE_CONTROLLER
        Port map (
            clk             => clk_100mhz,
            reset           => reset,
            start           => start_stop,         -- Use start/stop control
            IL_max_comp     => il_max_comp1_D2,       -- Connect comparator signal 1 (max current)
            IL_min_comp     => il_min_comp1_D2,       -- Connect comparator signal 1 (min current)
            delay_hc        => measured_delay_hc,  -- Use measured delay for HC from delay_measurement
            delay_tr        => measured_delay_tr,  -- Use measured delay for TR from delay_measurement
            S1              => s1_phy,                 -- Output to transistor S1
            S2              => s2_phy,                 -- Output to transistor S2
        	T01  			=> shift_flag_start,
        	T12  			=> OPEN,    			
        	T23  			=> OPEN,    			
        	T45  			=> OPEN    			
        );
	-- Two D flip flop to prevent metastability
	SB_DFF_inst_PH2_MAX_D1: SB_DFF
		port map (
			Q => il_max_comp2_D1, -- Registered Output
			C => clk_100mhz, -- Clock
			D => il_max_comp2 -- Data
		);
		SB_DFF_inst_PH2_MAX_D2: SB_DFF
		port map (
			Q => il_max_comp2_D2, -- Registered Output
			C => clk_100mhz, -- Clock
			D => il_max_comp2_D1 -- Data
		);
		
	SB_DFF_inst_PH2_MIN_D1: SB_DFF
		port map (
			Q => il_min_comp2_D1, -- Registered Output
			C => clk_100mhz, -- Clock
			D => il_min_comp2 -- Data
		);
		SB_DFF_inst_PH2_MIN_D2: SB_DFF
		port map (
			Q => il_min_comp2_D2, -- Registered Output
			C => clk_100mhz, -- Clock
			D => il_min_comp2_D1 -- Data
		);
    -- Instantiate the second PHASE_CONTROLLER module (for controlling S3 and S4)
    phase_controller_slave: PHASE_CONTROLLER_SECOND
        Port map (
            clk             => clk_100mhz,
            reset           => reset,
            start           => start_stop,         -- Same start/stop control
            start_flag      => shift_flag_start,         
            IL_max_comp     => il_max_comp2_D2,       -- Connect comparator signal 2 (max current)
            IL_min_comp     => il_min_comp2_D2,       -- Connect comparator signal 2 (min current)
            delay_hc        => measured_delay_hc,  -- Same measured delay for HC
            delay_tr        => measured_delay_tr,  -- Same measured delay for TR
            S1              => s3_phy,                 -- Output to transistor S3
            S2              => s4_phy,                -- Output to transistor S4
        	T01  			=> open,
        	T12  			=> open,    			
        	T23  			=> open,    			
        	T45  			=> open   
            -- Error output signal
            
        );
      --  process(s1_phy,s3_phy)
    --begin
    --    S1_buffor<=s1_phy;
	--	S3_buffor<=s3_phy;
   -- end process;
		 -- Instantiate the current_shift module to calculate the integer value
    current_shift_inst: current_shift
        Port map (
            clk             => clk_10khz,
            clk2            => clk_100mhz,
            reset           => reset,
            enable          => start_stop,         -- enable
            S1              => s1_phy,                -- Input S1 signal
            S3              => s3_phy,                -- Input S3 signal
            control_out     => pwm_duty_input     -- Output for PWM duty cycle control  
        );

    -- Instantiate the PWM_GENERATOR to convert integer from current_shift into PWM signal
    pwm_generator_inst: PWM_GENERATOR
        Port map (
            clk => clk_100mhz,
            reset => reset,
            duty_input => pwm_duty_input,  -- Input from current_shift integer output
            pwm_out => pwm_output          -- Output PWM signal to be read by the microcontroller
        );
        
        
        rgb_drv: SB_RGBA_DRV
        generic map(
        		CURRENT_MODE => "0b0",
                RGB0_CURRENT =>  "0b111111",
                RGB1_CURRENT => "0b111111",
                RGB2_CURRENT => "0b111111"
                )
        port map (
            CURREN   => '1',          -- Enable current control
            RGBLEDEN => '1',    -- Enable RGB driver
            RGB0PWM  => red,         -- Red PWM signal from LEDDA IP
            RGB1PWM  => green,         -- Green PWM signal from LEDDA IP
            RGB2PWM  => blue,         -- Blue PWM signal from LEDDA IP
            RGB0     => rgb_r,         -- Red LED output
            RGB1     => rgb_g,         -- Green LED output
            RGB2     => rgb_b          -- Blue LED output
        );
    
    process(start_stop, reset)
    begin
        if start_stop = '0' AND reset = '0' then
        red <= '0';
        green <= '0';
        blue <= '1';
        end if;
        if start_stop = '0'  AND reset = '1' then
        red <= '1';
        green <= '0';
        blue <= '0';
        end if;
        if start_stop = '1' AND reset = '0' then
        red <= '0';
        green <= '1';
        blue <= '0';
        end if;
        if start_stop = '1'  AND reset = '1' then
        red <= '1';
        green <= '0';
        blue <= '1';
        end if;
    end process;
    
end Behavioral;