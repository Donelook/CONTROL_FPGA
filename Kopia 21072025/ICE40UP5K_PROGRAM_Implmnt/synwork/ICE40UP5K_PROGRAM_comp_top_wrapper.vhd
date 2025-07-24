--
-- Synopsys
-- Vhdl wrapper for top level design, written on Thu Jan 30 00:21:18 2025
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wrapper_for_MAIN is
   port (
      reset : in std_logic;
      start_stop : in std_logic;
      il_max_comp1 : in std_logic;
      il_max_comp2 : in std_logic;
      il_min_comp1 : in std_logic;
      il_min_comp2 : in std_logic;
      delay_tr_input : in std_logic;
      delay_hc_input : in std_logic;
      s1_phy : out std_logic;
      s2_phy : out std_logic;
      s3_phy : out std_logic;
      s4_phy : out std_logic;
      pwm_output : out std_logic;
      rgb_r : out std_logic;
      rgb_g : out std_logic;
      rgb_b : out std_logic;
      T01 : out std_logic;
      T12 : out std_logic;
      T23 : out std_logic;
      T45 : out std_logic;
      clock_output : out std_logic
   );
end wrapper_for_MAIN;

architecture behavioral of wrapper_for_MAIN is

component MAIN
 port (
   reset : in std_logic;
   start_stop : in std_logic;
   il_max_comp1 : in std_logic;
   il_max_comp2 : in std_logic;
   il_min_comp1 : in std_logic;
   il_min_comp2 : in std_logic;
   delay_tr_input : in std_logic;
   delay_hc_input : in std_logic;
   s1_phy : out std_logic;
   s2_phy : out std_logic;
   s3_phy : out std_logic;
   s4_phy : out std_logic;
   pwm_output : out std_logic;
   rgb_r : out std_logic;
   rgb_g : out std_logic;
   rgb_b : out std_logic;
   T01 : out std_logic;
   T12 : out std_logic;
   T23 : out std_logic;
   T45 : out std_logic;
   clock_output : out std_logic
 );
end component;

signal tmp_reset : std_logic;
signal tmp_start_stop : std_logic;
signal tmp_il_max_comp1 : std_logic;
signal tmp_il_max_comp2 : std_logic;
signal tmp_il_min_comp1 : std_logic;
signal tmp_il_min_comp2 : std_logic;
signal tmp_delay_tr_input : std_logic;
signal tmp_delay_hc_input : std_logic;
signal tmp_s1_phy : std_logic;
signal tmp_s2_phy : std_logic;
signal tmp_s3_phy : std_logic;
signal tmp_s4_phy : std_logic;
signal tmp_pwm_output : std_logic;
signal tmp_rgb_r : std_logic;
signal tmp_rgb_g : std_logic;
signal tmp_rgb_b : std_logic;
signal tmp_T01 : std_logic;
signal tmp_T12 : std_logic;
signal tmp_T23 : std_logic;
signal tmp_T45 : std_logic;
signal tmp_clock_output : std_logic;

begin

tmp_reset <= reset;

tmp_start_stop <= start_stop;

tmp_il_max_comp1 <= il_max_comp1;

tmp_il_max_comp2 <= il_max_comp2;

tmp_il_min_comp1 <= il_min_comp1;

tmp_il_min_comp2 <= il_min_comp2;

tmp_delay_tr_input <= delay_tr_input;

tmp_delay_hc_input <= delay_hc_input;

s1_phy <= tmp_s1_phy;

s2_phy <= tmp_s2_phy;

s3_phy <= tmp_s3_phy;

s4_phy <= tmp_s4_phy;

pwm_output <= tmp_pwm_output;

rgb_r <= tmp_rgb_r;

rgb_g <= tmp_rgb_g;

rgb_b <= tmp_rgb_b;

T01 <= tmp_T01;

T12 <= tmp_T12;

T23 <= tmp_T23;

T45 <= tmp_T45;

clock_output <= tmp_clock_output;



u1:   MAIN port map (
		reset => tmp_reset,
		start_stop => tmp_start_stop,
		il_max_comp1 => tmp_il_max_comp1,
		il_max_comp2 => tmp_il_max_comp2,
		il_min_comp1 => tmp_il_min_comp1,
		il_min_comp2 => tmp_il_min_comp2,
		delay_tr_input => tmp_delay_tr_input,
		delay_hc_input => tmp_delay_hc_input,
		s1_phy => tmp_s1_phy,
		s2_phy => tmp_s2_phy,
		s3_phy => tmp_s3_phy,
		s4_phy => tmp_s4_phy,
		pwm_output => tmp_pwm_output,
		rgb_r => tmp_rgb_r,
		rgb_g => tmp_rgb_g,
		rgb_b => tmp_rgb_b,
		T01 => tmp_T01,
		T12 => tmp_T12,
		T23 => tmp_T23,
		T45 => tmp_T45,
		clock_output => tmp_clock_output
       );
end behavioral;
